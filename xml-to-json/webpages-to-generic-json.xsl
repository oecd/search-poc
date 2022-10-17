<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/2005/xpath-functions" xmlns:saxon="http://saxon.sf.net/">
    <xsl:output method="text" indent="yes" encoding="UTF-8"/>

    <!--
        this is just a quick and dirty way to convert a lot of XML to JSON quickly
        in the format required by the Azure search engine
        -->
    <xsl:template match="/">
        <xsl:for-each select="/Pages/page/copy-of()" saxon:threads="8">
            <xsl:apply-templates select=".">
                <xsl:with-param name="number" select="position()"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="page">
        <xsl:param name="number"/>
        <xsl:variable name="lang" select="language"/>
        <!-- only taking the first category as the model does not allow for more - POC limitation -->
        <xsl:variable name="type">
            <xsl:choose>
                <xsl:when test="doc_category[text()]">
                    <xsl:value-of select="replace(lower-case(normalize-space(tokenize(doc_category, ',')[1])), 's$', '')"
                    />
                </xsl:when>
                <xsl:otherwise>web page</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="normalized-id" select="concat(id, '-', $number)"/>
        <!-- take the year of publication as the directory to divide the pages into -->
        <xsl:variable name="dir" select="tokenize(date_published, '-')[1]"/>
        <xsl:variable name="url" select="concat('https://oecd.org', normalize-space(tokenize(urls, ',')[1]))"/>

        <xsl:variable name="xml">
            <map>
                <string key="id"><xsl:value-of select="$normalized-id"/></string>
                <string key="domain">web page</string>
                <string key="type"><xsl:value-of select="$type"/></string>
                <!-- title -->
                <string key="{concat('title_', $lang)}"><xsl:value-of select="normalize-space(name)"/></string>
                <!-- date -->
                <string key="date"><xsl:value-of select="concat(date_published, 'Z')"/></string>
                <!-- target url -->
                <string key="url"><xsl:value-of select="$url"/></string>
                <!-- language, there is only ever one -->
                <array key="languages">
                    <string><xsl:value-of select="$lang"/></string>
                </array>
                <!-- description -->
                <xsl:if test="blurb/text()">
                    <string key="{concat('description_', $lang)}"><xsl:value-of select="normalize-space(blurb)"/></string>
                </xsl:if>
                <!-- topics -->
                <xsl:if test="topics">
                    <array key="subjects_en">
                        <xsl:for-each select="tokenize(topics, ',')">
                            <string><xsl:value-of select="normalize-space(.)"/></string>
                        </xsl:for-each>
                    </array>
                </xsl:if>
                <!-- size-type data unavailable -->
                <!-- image_url unavailable -->
                <string key="image_url">https://picsum.photos/340/460</string>
            </map>
        </xsl:variable>
        <!-- OUTPUT -->
        <xsl:variable name="outFile" select="concat('../data/web-pages/', $dir, '/', $normalized-id, '.json')"/>
        <xsl:message>Writing to: <xsl:value-of select="$outFile"/></xsl:message>
        <xsl:result-document href="{$outFile}">
            <xsl:value-of select="xml-to-json($xml)"/>
        </xsl:result-document>
    </xsl:template>

</xsl:stylesheet>
