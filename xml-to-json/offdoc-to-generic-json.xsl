<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns="http://www.w3.org/2005/xpath-functions"
    xmlns:saxon="http://saxon.sf.net/">
    <xsl:output method="text" indent="yes" encoding="UTF-8"/>
        
    <!--
        this is just a quick and dirty way to convert a lot of XML to JSON quickly
        in the format required by the Azure search engine
        -->
    <xsl:template match="/">
        <xsl:for-each select="/off-docs/off-doc/copy-of()" saxon:threads="8">
            <xsl:apply-templates select=".">
                <xsl:with-param name="number" select="position()"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="off-doc">
        <xsl:param name="number"/>
        <xsl:variable name="langs" select="languages/language"/>
        <xsl:variable name="type" select="tokenize(type, '/')[last()]"/>
        <xsl:variable name="normalized-id" select="replace(replace(replace(lower-case(id),'/', '-'), '\(', '-'), '\)', '-')"/>
        <xsl:variable name="dir" select="tokenize($normalized-id, '-')[1]"/>
        <xsl:variable name="file-lang" select="tokenize(url, '/')[last()-1]"/>
        
        <xsl:variable name="xml">
            <map>
                <string key="id"><xsl:value-of select="concat($normalized-id, '-', $file-lang, '-', $number)"/></string>
                <string key="domain">official document</string>
                <!-- can be one of three: official document, agenda, minutes of agenda -->
                <string key="type"><xsl:value-of select="$type"/></string>
                <string key="{concat('title_', $file-lang)}"><xsl:value-of select="concat(id, ' - ', title)"/></string>
                <string key="date"><xsl:value-of select="concat(date, 'Z')"/></string>
                <string key="url"><xsl:value-of select="url"/></string>
                <array key="lanugages">
                    <xsl:for-each select="$langs">
                        <string><xsl:value-of select="."/></string>
                    </xsl:for-each>
                </array>
                <xsl:if test="summary/text()">
                    <string key="{concat('description_', $file-lang)}">
                        <xsl:value-of select="summary"/>
                    </string>
                </xsl:if>
                <xsl:if test="topics">
                    <!-- no hyphens accepted, need to use underscore -->
                    <array key="subjects_en">
                        <xsl:for-each select="tokenize(topics, ',')">
                            <string><xsl:value-of select="normalize-space(.)"/></string>
                        </xsl:for-each>
                    </array>
                </xsl:if>
                <xsl:if test="number-of-pages and number-of-pages ne '0'">
                    <string key="size">
                        <xsl:value-of select="number-of-pages/text()"/> pages
                    </string>
                </xsl:if>
                <string key="image_url">
                    <xsl:choose>
                        <xsl:when test="$type eq 'official document'">https://placekitten.com/340/460</xsl:when>
                        <xsl:when test="$type eq 'agenda'">https://picsum.photos/id/175/340/460</xsl:when>
                        <xsl:otherwise>https://picsum.photos/340/460</xsl:otherwise>
                    </xsl:choose>
                </string>
            </map>
        </xsl:variable>
        <!-- OUTPUT -->
        <xsl:variable name="outFile" 
            select="concat('../data/official-documents/', $dir, '/', $normalized-id, '-', $file-lang, '-', $number, '.json')"/>
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
