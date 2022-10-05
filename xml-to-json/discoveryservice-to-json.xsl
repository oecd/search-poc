<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xpath-default-namespace="http://oecd.metastore.ingenta.com/ns/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:prism="http://prismstandard.org/namespaces/1.2/basic/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/2005/xpath-functions">
    <xsl:output method="text" encoding="UTF-8"/>

    <xsl:variable name="root" select="/"/>
    <xsl:variable name="inputDirBase" select="'file:///c:/repos/git/DiscoveryService/metadata/2.0/oecd/'"/>
    
    <!--
        this is just a quick and dirty way to convert a lot of XML to JSON quickly
        in the format required by the Azure search engine
        
        at this point it doesn't take into consideration the limit of 1000 documents 
        or 16 MB, but as it's just to get some results, this will do right now.
        
        {
            "value": [
                {
                    "@search.action": "upload",
                    "id": ...
                    ...
                },
                ...
            ]
        }
        -->
    <xsl:template match="/">
        <xsl:for-each select="('article', 'book', 'dataset', 'indicator', 'issue', 'podcast', 'summary', 'workingpaper')">
            <xsl:variable name="inputDir" select="concat($inputDirBase, '/', ., '/?select=*.xml')"/>
            <xsl:message><xsl:value-of select="$inputDir"/></xsl:message>

            <xsl:variable name="xml">
                <map>
                    <array key="value">
                        <xsl:for-each select="collection($inputDir)">
                            <xsl:apply-templates select="*" mode="json"/>
                        </xsl:for-each>
                    </array>
                </map>
            </xsl:variable>
            <!-- OUTPUT -->
            <xsl:variable name="outFile" select="concat('file:///c:/temp/', . ,'.json')"/>
            <xsl:message>Writing to: <xsl:value-of select="$outFile"/></xsl:message>
            <xsl:result-document href="{$outFile}">
                <xsl:value-of select="xml-to-json($xml)"/>
            </xsl:result-document>
        </xsl:for-each>
    </xsl:template>
    
    <!--
        This template matches the root elements we may encounter and generates 
        an XML node that can then be passed to the xml-to-json() function to 
        generate correct JSON.
        -->
    <xsl:template match="Book | Article | Dataset | Indicator | Podcast | Workingpaper" mode="json">
        <xsl:message>in a <xsl:value-of select="local-name()"/></xsl:message>
        <xsl:variable name="id" select="tokenize(doi/@rdf:resource, '/')[last()]"/>
        <xsl:variable name="type" select="lower-case(local-name(.))"/>
        <xsl:variable name="lang" select="dc:language/text()"/>

        <map>
            <!-- this is required by Azure search as instruction what to do with the document -->
            <string key="@search.action">upload</string>
            <!-- we use the type for facetting in the end user interface -->
            <string key="type"><xsl:value-of select="$type"/></string>
            <!-- this is the primary key -->
            <string key="id"><xsl:value-of select="$id"/></string>
            <string key="doi"><xsl:value-of select="doi/@rdf:resource"/></string>
            <xsl:if test="isbn"><string key="isbn"><xsl:value-of select="isbn/text()"/></string></xsl:if>
            <!-- language is used for facetting, for example -->
            <string key="language"><xsl:value-of select="$lang"/></string>
            <xsl:if test="numberOfPages"><number key="numberOfPages"><xsl:value-of select="pageCount/text()"/></number></xsl:if>
            <!-- specific for podcasts, can't use number as it's a string -->
            <xsl:if test="duration"><string key="duration"><xsl:value-of select="duration/text()"/></string></xsl:if>
            <!-- I strongly assume we store UTC, so I simply add a "Z" to the end to make it explicit (required by index) -->
            <string key="publicationDate"><xsl:value-of select="concat(prism:publicationDate, 'Z')"/></string>
            <!-- english title -->
            <string key="title"><xsl:value-of select="dc:title[@xml:lang='en']"/></string>
            <!-- french title TODO -->
            <!-- subtitle only in English at this point -->
            <xsl:if test="subTitle[en]">
                <string key="subTitle"><xsl:value-of select="subTitle[en]"/></string>
            </xsl:if>
            <xsl:if test="dc:description">
                <map key="description">
                    <xsl:for-each select="dc:description">
                        <string key="{@xml:lang}"><xsl:value-of select="text()"
                        /></string>
                    </xsl:for-each>
                </map>
            </xsl:if>
            <xsl:if test="subject/dc:title[@xml:lang = 'en']">
                <!-- no hyphens accepted, need to use underscore -->
                <array key="subjects_en">
                    <xsl:for-each select="subject/dc:title[@xml:lang = 'en']">
                        <string><xsl:value-of select="text()"/></string>
                    </xsl:for-each>
                </array>
            </xsl:if>
            <xsl:if test="subject/dc:title[@xml:lang = 'fr']">
                <array key="subjects_fr">
                    <xsl:for-each select="subject/dc:title[@xml:lang = 'fr']">
                        <string><xsl:value-of select="text()"/></string>
                    </xsl:for-each>
                </array>
            </xsl:if>
            <array key="authors">
                <xsl:for-each select="authors/Author">
                    <string><xsl:value-of select="name"/></string>
                </xsl:for-each>
            </array>
            <!-- specific for podcasts -->
            <xsl:if test="host">
                <array key="hosts">
                    <xsl:for-each select="host">
                        <string><xsl:value-of select="text()"/></string>
                    </xsl:for-each>
                </array>
            </xsl:if>
            <!-- specific for podcasts -->
            <xsl:if test="speaker">
                <array key="speakers">
                    <xsl:for-each select="speaker">
                        <string><xsl:value-of select="text()"/></string>
                    </xsl:for-each>
                </array>
            </xsl:if>
            <!-- yes, for the time being simply concatenate all languages and add the city -->
            <array key="publishers">
                <xsl:for-each select="publishers/Publisher">
                    <string><xsl:value-of select="dc:title, city"/></string>
                </xsl:for-each>
            </array>
            <!-- only index one thumbnail (we won't search for it, it's just for display) -->
            <string key="thumbnail"><xsl:value-of select="
                concat('https:', (coverImages/coverImage[@width='340']/@href, 
                '//assets.oecdcode.org/covers/340/default.jpg')[1])
                "/>
            </string>
        </map>
    </xsl:template>
</xsl:stylesheet>
