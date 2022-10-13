<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns="http://www.w3.org/2005/xpath-functions"
    xmlns:saxon="http://saxon.sf.net/">
    <xsl:output method="text" encoding="UTF-8"/>
        
    <!--
        this is just a quick and dirty way to convert a lot of XML to JSON quickly
        in the format required by the Azure search engine
        -->
    <xsl:template match="/">
        <xsl:for-each select="/off-docs/off-doc/copy-of()" saxon:threads="4">
            <xsl:apply-templates select=".">
                <xsl:with-param name="number" select="position()"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="off-doc">
        <xsl:param name="number"/>
        <xsl:variable name="langs" select="languages/language"/>
        <xsl:variable name="id" select="replace(replace(replace(lower-case(id),'/', '-'), '\(', '-'), '\)', '-')"/>
        <xsl:variable name="dir" select="tokenize($id, '-')[1]"/>
        <xsl:variable name="url" select="url"/>
        <xsl:variable name="xml">
            <map>
                <array key="value">
                    <map>
                        <string key="@search.action">upload</string>
                        <string key="domain">official document</string>
                        <string key="id"><xsl:value-of select="concat(id, '-', languages/language[1])"/></string>
                        <string key="url"><xsl:value-of select="$url"/></string>
                        <array key="lanugage"><xsl:for-each select="$langs">
                            <string><xsl:value-of select="."/></string>
                        </xsl:for-each></array>
                        <!-- can be one of three: official document, agenda, minutes of agenda -->
                        <string key="type"><xsl:value-of select="tokenize(type, '/')[last()]"/></string>
                        <string key="title"><xsl:value-of select="title"/></string>
                        <string key="publicationDate"><xsl:value-of select="concat(date, 'Z')"/></string>
                        <xsl:if test="summary/text()">
                            <map key="description">
                                <string key="{$langs[1]}"><xsl:value-of select="summary"/></string>
                            </map>  
                        </xsl:if>
                        <xsl:if test="number-of-pages and number-of-pages ne '0'">
                            <number key="numberOfPages"><xsl:value-of select="number-of-pages/text()"/></number>
                        </xsl:if>
                        <xsl:if test="topics">
                            <!-- no hyphens accepted, need to use underscore -->
                            <array key="subjects_en">
                                <xsl:for-each select="tokenize(topics, ',')">
                                    <string><xsl:value-of select="normalize-space(.)"/></string>
                                </xsl:for-each>
                            </array>
                        </xsl:if>
                        
                        <!--<xsl:message><xsl:value-of select="document-uri(.)"/></xsl:message>-->                        
                    </map>
                </array>
            </map>
        </xsl:variable>
        <!-- OUTPUT -->
        <xsl:variable name="outFile" select="concat('../data/official-documents/', $dir, '/', $id, '-', languages/language[1], '-', $number, '.json')"/>
        <xsl:message>Writing to: <xsl:value-of select="$outFile"/></xsl:message>
        <xsl:result-document href="{$outFile}">
            <xsl:value-of select="xml-to-json($xml)"/>
        </xsl:result-document>        
    </xsl:template>
    
    <!--
        This template matches the root elements we may encounter and generates 
        an XML node that can then be passed to the xml-to-json() function to 
        generate correct JSON.
        -->
    <xsl:template match="Book | Article | Dataset | Indicator | Podcast | WorkingPaper | Summary" mode="json">
        <xsl:variable name="id" select="tokenize(doi/@resource, '/')[last()]"/>
        <xsl:variable name="type" select="lower-case(local-name(.))"/>
        <xsl:variable name="lang" select="language/text()"/>
        
        <xsl:choose>
            <xsl:when test="$lang = 'en' or $lang = 'fr'">
                <map>
                    
                    <!-- french title TODO -->
                    <xsl:if test="subTitle[en]">
                        <string key="subTitle"><xsl:value-of select="subTitle[en]"/></string>
                    </xsl:if>
                    <xsl:if test="description[@lang='en' or @lang='fr']">
                        <map key="description">
                            <xsl:for-each select="description[@lang='en' or @lang='fr']">
                                <string key="{@lang}"><xsl:value-of select="text()"
                                /></string>
                            </xsl:for-each>
                        </map>
                    </xsl:if>
                    <xsl:if test="subject/title[@lang = 'en']">
                        <!-- no hyphens accepted, need to use underscore -->
                        <array key="subjects_en">
                            <xsl:for-each select="subject/title[@lang = 'en']">
                                <string><xsl:value-of select="text()"/></string>
                            </xsl:for-each>
                        </array>
                    </xsl:if>
                    <xsl:if test="subject/title[@lang = 'fr']">
                        <array key="subjects_fr">
                            <xsl:for-each select="subject/title[@lang = 'fr']">
                                <string><xsl:value-of select="text()"/></string>
                            </xsl:for-each>
                        </array>
                    </xsl:if>
                    <array key="authors">
                        <xsl:for-each select="authors/Author">
                            <string><xsl:value-of select="name"/></string>
                        </xsl:for-each>
                    </array>
                    <xsl:if test="host">
                        <array key="hosts">
                            <xsl:for-each select="host">
                                <string><xsl:value-of select="text()"/></string>
                            </xsl:for-each>
                        </array>
                    </xsl:if>
                    <xsl:if test="speaker">
                        <array key="speakers">
                            <xsl:for-each select="speaker">
                                <string><xsl:value-of select="text()"/></string>
                            </xsl:for-each>
                        </array>
                    </xsl:if>
                    <array key="publishers">
                        <xsl:for-each select="publishers/Publisher">
                            <string><xsl:value-of select="title, city"/></string>
                        </xsl:for-each>
                    </array> 
                    <string key="thumbnail"><xsl:value-of 
                        select="concat('https:', (coverImages/coverImage[@width='340']/@href, 
                        '//assets.oecdcode.org/covers/340/default.jpg')[1])
                        "/></string>
                </map>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>Currently ignoring documents in language: <xsl:value-of select="$lang"/>, sorry! :-(</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="isPartOf|articles|tables|graphs" mode="#all"/>
</xsl:stylesheet>
