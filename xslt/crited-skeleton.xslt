<?xml version="1.0" encoding="UTF-8"?>
<!--
  ==========================================================================
  crited-skeleton.xslt
  ==========================================================================
  PURPOSE
    Derives the skeleton of a digital critical edition from a diplomatic
    TEI transcription (e.g. ms002_I-Vlevi_CF.C.9.xml). The result keeps the
    structure and text of the transcription, but:
      - gets a new edition title,
      - loses the line-based layout markup (lb, milestone),
      - gets new, edition-specific @xml:id values in tei:text, each one
        pointing back to the corresponding element of the transcription
        via @corresp.

  WHAT HAPPENS, STEP BY STEP
    1. teiHeader
       - Copied unchanged, except:
       - titleStmt/title[@type='main'] is replaced by the edition title
         (parameter "editionTitle"). The title inside sourceDesc/bibl
         describes the source and is therefore NOT changed.
       - Every idno whose @type is listed in "removeIdnoTypes"
         (default: Transkribus) is deleted, together with the whitespace
         (line break + indentation) in front of it, so no empty line remains.
       - revisionDesc gets a new change entry documenting this run:
           <change n="(last n + 1)" when="(today)">
              <note>Transformation with crited-skeleton.xslt ...</note>
           </change>
         (if there is no revisionDesc, one is created).

    2. facsimile (and everything else outside tei:text)
       Copied unchanged.

    3. tei:text and all its descendants
       a) @corresp: every element that has an @xml:id gets a pointer to
          its original id:  xml:id="ms002_text"  ->  corresp="#ms002_text"
          If the element already has a @corresp, the new pointer is added
          in front of the existing value (TEI allows a list of pointers).
       b) @xml:id: the prefix "sourcePrefix" (e.g. "ms002_") is replaced
          by "targetPrefix" (e.g. "ce001_"):
            xml:id="ms002_d1_p1"  ->  xml:id="ce001_d1_p1"
          IDs that do not start with "sourcePrefix" are kept as they are.
       c) tei:lb and tei:milestone are removed.
       d) Whitespace clean-up: lb and milestone usually stand on their own
          line or at the start of a line. Simply dropping them would leave
          empty lines behind. Therefore all runs of adjacent text nodes,
          lb and milestone are merged into one string and normalised:
            - an lb with @break="no" (word split across two lines, e.g.
              "appoggia<lb break='no'/>tura") joins the two parts directly:
              the whitespace around it is deleted -> "appoggiatura";
              this also works across a page break:
              "<w>secon <pb/> <lb break='no'/>do</w>" -> "<w>secon<pb/>do</w>";
            - any whitespace sequence containing one or more line breaks is
              reduced to exactly ONE line break followed by the indentation
              of the last line. Thus empty lines disappear while the normal
              line-by-line layout of the text is preserved.
          All other attributes (@facs, @n, @rend ...) and all other
          elements (pb, notatedMusic, w, choice, g ...) are kept.

  REUSE
    Only the CONFIGURATION section (or transformation parameters, e.g. in
    Oxygen or on the Saxon command line) needs to be adapted:
      editionTitle     title of the critical edition
      targetPrefix     ID prefix of the edition, e.g. "ce002_"
      sourcePrefix     ID prefix of the transcription. Leave empty to derive
                       it automatically from tei:text/@xml:id (everything
                       up to and including the first "_", e.g.
                       "ms002_text" -> "ms002_").
      removeIdnoTypes  space-separated list of idno/@type values to delete
      changeNote       text of the new revisionDesc entry

    Saxon command line example:
      java -jar saxon9.jar -s:ms003.xml -xsl:crited-skeleton.xslt
           -o:ce002.xml targetPrefix=ce002_
           "editionTitle=Digital Critical Edition of ..."

  REQUIREMENTS
    XSLT 2.0 processor (e.g. Saxon HE/PE/EE, as used by Oxygen XML Editor).
  ==========================================================================
-->
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="#all">

    <!-- ====================================================================
         OUTPUT SETTINGS
         indent="no" keeps the layout of the source; the whitespace clean-up
         in tei:text is done explicitly (see step 3d).
         ==================================================================== -->
    <xsl:output method="xml" encoding="UTF-8" indent="no"/>


    <!-- ====================================================================
         CONFIGURATION (the only section to adapt for other documents)
         ==================================================================== -->

    <!-- Title of the critical edition (replaces titleStmt/title[@type='main']). -->
    <xsl:param name="editionTitle" as="xs:string"
        select="'Digital Critical Edition of Regole per ben suonare il violino'"/>

    <!-- New ID prefix for tei:text and its descendants. -->
    <xsl:param name="targetPrefix" as="xs:string" select="'ce001_'"/>

    <!-- Old ID prefix. Empty = derive it from tei:text/@xml:id. -->
    <xsl:param name="sourcePrefix" as="xs:string" select="''"/>

    <!-- idno types to be removed from the teiHeader (space-separated). -->
    <xsl:param name="removeIdnoTypes" as="xs:string" select="'Transkribus'"/>

    <!-- Text of the new revisionDesc/change/note. By default it names this
         stylesheet's file name, so it stays correct if the file is renamed. -->
    <xsl:param name="changeNote" as="xs:string" select="
        concat('Transformation with ', tokenize(static-base-uri(), '/')[last()],
               ' (skeleton of the digital critical edition)')"/>


    <!-- ====================================================================
         DERIVED VALUES (no need to change)
         ==================================================================== -->

    <!-- Effective old prefix: the parameter, or the part of
         tei:text/@xml:id up to and including the first "_". -->
    <xsl:variable name="oldPrefix" as="xs:string" select="
        if ($sourcePrefix != '') then $sourcePrefix
        else concat(substring-before((/tei:TEI/tei:text/@xml:id)[1], '_'), '_')"/>

    <!-- idno types to remove, as a sequence of strings. -->
    <xsl:variable name="idnoTypesToRemove" as="xs:string*"
        select="tokenize(normalize-space($removeIdnoTypes), ' ')"/>

    <!-- Placeholder for lb[@break='no'] while text is merged (step 3d).
         A Unicode private-use character that never occurs in the text. -->
    <xsl:variable name="joinMark" as="xs:string" select="'&#xE000;'"/>


    <!-- ====================================================================
         DEFAULT: identity transformation
         Everything not matched by a more specific template is copied as is
         (elements, attributes, text, comments, processing instructions).
         ==================================================================== -->
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>


    <!-- ====================================================================
         STEP 1: teiHeader
         ==================================================================== -->

    <!-- 1a: Replace the main title of the edition (titleStmt only). -->
    <xsl:template match="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type = 'main']">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:value-of select="$editionTitle"/>
        </xsl:copy>
    </xsl:template>

    <!-- 1b: Remove the unwanted idno elements ... -->
    <xsl:template match="tei:teiHeader//tei:idno[@type = $idnoTypesToRemove]"/>

    <!-- ... and the whitespace-only text node (line break + indentation)
         directly in front of them, so that no empty line remains. -->
    <xsl:template match="tei:teiHeader//text()
        [not(normalize-space())]
        [following-sibling::node()[1][self::tei:idno[@type = $idnoTypesToRemove]]]"/>

    <!-- 1c: Document this transformation in revisionDesc.
         A new tei:change is appended after the last existing child:
           @n     = highest existing change/@n + 1 (1 if there is none)
           @when  = date of the transformation run (YYYY-MM-DD)
           note   = parameter "changeNote"
         The indentation is copied from the whitespace in front of the last
         existing change, so the new entry lines up with the others. -->
    <xsl:template match="tei:teiHeader/tei:revisionDesc">
        <!-- whitespace after the last child = indentation of </revisionDesc> -->
        <xsl:variable name="closingWs" as="xs:string" select="
            string(node()[last()][self::text()][not(normalize-space())])"/>
        <!-- indentation of a change element (fallback: closing + 3 spaces) -->
        <xsl:variable name="changeWs" as="xs:string" select="
            if (tei:change) then
                string(tei:change[last()]/preceding-sibling::node()[1]
                       [self::text()][not(normalize-space())])
            else concat($closingWs, '   ')"/>
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <!-- all children except the trailing whitespace -->
            <xsl:apply-templates select="node() except
                node()[last()][self::text()][not(normalize-space())]"/>
            <xsl:value-of select="$changeWs"/>
            <xsl:call-template name="new-change">
                <xsl:with-param name="indent" select="$changeWs"/>
                <xsl:with-param name="n" select="
                    max((0, tei:change/@n[. castable as xs:integer]/xs:integer(.))) + 1"/>
            </xsl:call-template>
            <xsl:value-of select="$closingWs"/>
        </xsl:copy>
    </xsl:template>

    <!-- 1c (fallback): no revisionDesc yet -> create one at the end of the
         teiHeader (TEI requires revisionDesc to be its last child). -->
    <xsl:template match="tei:teiHeader[not(tei:revisionDesc)]">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
            <revisionDesc>
                <xsl:call-template name="new-change">
                    <xsl:with-param name="indent" select="'&#10;'"/>
                    <xsl:with-param name="n" select="1"/>
                </xsl:call-template>
            </revisionDesc>
        </xsl:copy>
    </xsl:template>

    <!-- Builds the new change element (used by both templates above). -->
    <xsl:template name="new-change">
        <xsl:param name="indent" as="xs:string"/>
        <xsl:param name="n" as="xs:integer"/>
        <change n="{$n}" when="{format-date(current-date(), '[Y0001]-[M01]-[D01]')}">
            <xsl:value-of select="concat($indent, '   ')"/>
            <note>
                <xsl:value-of select="$changeNote"/>
            </note>
            <xsl:value-of select="$indent"/>
        </change>
    </xsl:template>


    <!-- ====================================================================
         STEP 3: tei:text and all its descendants (mode "edition")
         ==================================================================== -->

    <!-- Entry point: switch to mode "edition" for the whole tei:text. -->
    <xsl:template match="tei:text">
        <xsl:apply-templates select="." mode="edition"/>
    </xsl:template>

    <!-- Every element inside tei:text:
         copy it, rewrite its ids (3a, 3b) and process its children with the
         whitespace-aware routine (3c, 3d). -->
    <xsl:template match="*" mode="edition">
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="edition"/>
            <xsl:call-template name="process-children"/>
        </xsl:copy>
    </xsl:template>

    <!-- 3a + 3b: @xml:id gets the new prefix, the original id becomes
         @corresp (merged with an already existing @corresp). -->
    <xsl:template match="@xml:id" mode="edition">
        <xsl:attribute name="xml:id" select="
            if (starts-with(., $oldPrefix))
            then concat($targetPrefix, substring-after(., $oldPrefix))
            else string(.)"/>
        <xsl:attribute name="corresp" select="
            normalize-space(concat('#', ., ' ', ../@corresp))"/>
    </xsl:template>

    <!-- An existing @corresp is already written by the @xml:id template
         above; copy it here only if the element has no @xml:id. -->
    <xsl:template match="@corresp[../@xml:id]" mode="edition"/>

    <!-- All other attributes are copied unchanged. -->
    <xsl:template match="@*" mode="edition">
        <xsl:copy/>
    </xsl:template>

    <!-- Comments and processing instructions are copied unchanged. -->
    <xsl:template match="comment() | processing-instruction()" mode="edition">
        <xsl:copy/>
    </xsl:template>

    <!-- 3c + 3d: Process the children of the current element.
         Consecutive text nodes, lb and milestone form one group; every
         other node (element, comment, PI) forms a group of its own.
         - Text groups: lb and milestone are dropped, the text is merged
           and its whitespace normalised (see function-like steps below).
         - Other nodes: processed recursively in mode "edition". -->
    <xsl:template name="process-children">
        <xsl:for-each-group select="node()"
            group-adjacent="boolean(self::text() | self::tei:lb | self::tei:milestone)">
            <xsl:choose>
                <xsl:when test="current-grouping-key()">
                    <!-- (i) Merge the group into one string; an
                         lb[@break='no'] leaves the join mark behind, every
                         other lb and every milestone leaves nothing. -->
                    <xsl:variable name="groupText" as="xs:string" select="
                        string-join(
                            for $n in current-group()
                            return
                                if ($n instance of text()) then string($n)
                                else if ($n/self::tei:lb[@break = ('no', 'false')]) then $joinMark
                                else '',
                            '')"/>
                    <!-- (i b) Word split across a page break, e.g.
                         "secon <pb/> <milestone/> <lb break='no'/>do":
                         the lb[@break='no'] belongs to a LATER group, so
                         the trailing whitespace of THIS group (before the
                         pb) must be deleted as well. Look past pb,
                         milestone and whitespace-only text for the next
                         relevant node; if it is an lb[@break='no'] outside
                         this group, append the join mark here too. -->
                    <xsl:variable name="nextRelevant" as="node()?" select="
                        current-group()[last()]/following-sibling::node()
                            [not(self::tei:pb | self::tei:milestone
                                 | self::text()[not(normalize-space())])][1]"/>
                    <xsl:variable name="merged" as="xs:string" select="
                        if ($nextRelevant/self::tei:lb[@break = ('no', 'false')]
                            and not($nextRelevant intersect current-group()))
                        then concat($groupText, $joinMark)
                        else $groupText"/>
                    <!-- (ii) Word split across lines: delete the join mark
                         together with all whitespace around it. -->
                    <xsl:variable name="joined" as="xs:string"
                        select="replace($merged, concat('\s*', $joinMark, '\s*'), '')"/>
                    <!-- (iii) Remove empty lines: whitespace containing
                         line breaks becomes one line break plus the
                         indentation of the last line (greedy \s* swallows
                         all earlier breaks and trailing spaces). -->
                    <xsl:variable name="cleaned" as="xs:string"
                        select="replace($joined, '\s*(\n[ \t]*)', '$1')"/>
                    <xsl:value-of select="$cleaned"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="current-group()" mode="edition"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>

</xsl:stylesheet>
