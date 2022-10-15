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
        <xsl:variable name="normalized-id" select="replace(replace(replace(replace(lower-case(id),'/', '-'), '\(', '-'), '\)', '-'), '\.', '-')"/>
        <xsl:variable name="dir" select="tokenize($normalized-id, '-')[1]"/>
        <xsl:variable name="file-lang" select="tokenize(url, '/')[last()-1]"/>
        
        <xsl:variable name="xml">
            <map>
                <string key="id"><xsl:value-of select="concat($normalized-id, '-', $file-lang, '-', $number)"/></string>
                <string key="domain">official document</string>
                <!-- can be one of three: official document, agenda, minutes of agenda -->
                <string key="type"><xsl:value-of select="$type"/></string>
                <!-- title -->
                <string key="{concat('title_', $file-lang)}"><xsl:value-of select="normalize-space(concat(id, ' - ', title))"/></string>
                <string key="date"><xsl:value-of select="concat(date, 'Z')"/></string>
                <string key="url"><xsl:value-of select="url"/></string>
                <array key="languages">
                    <xsl:for-each select="$langs">
                        <string><xsl:value-of select="."/></string>
                    </xsl:for-each>
                </array>
                <xsl:if test="normalize-space(summary/text())">
                    <string key="{concat('description_', $file-lang)}"><xsl:value-of select="normalize-space(summary)"/></string>
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
                    <string key="size"><xsl:value-of select="normalize-space(number-of-pages/text())"/> pages</string>
                </xsl:if>
                <string key="image_url"><xsl:choose>
                        <xsl:when test="$type eq 'official document'">https://placekitten.com/340/460</xsl:when>
                        <xsl:when test="$type eq 'agenda'">https://picsum.photos/id/175/340/460</xsl:when>
                        <xsl:otherwise>https://picsum.photos/340/460</xsl:otherwise>
                    </xsl:choose></string>
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
    
</xsl:stylesheet>
