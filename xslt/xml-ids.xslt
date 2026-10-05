<?xml version="1.0" encoding="UTF-8"?>
<!--
  ==========================================================================
  xml-ids.xslt
  ==========================================================================
  PURPOSE
    Adds systematic, ascending @xml:id (and where required @n) attributes to
    the transcription part (tei:text/tei:body) of a TEI document. Everything
    else (elements, attributes, text, comments, processing instructions) is
    copied unchanged from the source document.

  WHAT IS GENERATED (example prefix "ms002_I-Vlevi_CF.C.9")
    div (top level)   xml:id="ms002_I-Vlevi_CF.C.9_d001"            n="1"
    div (nested)      xml:id="ms002_I-Vlevi_CF.C.9_d010_sd001"      n="1"
                      (deeper nesting appends a further _sd### per level)
    p                 xml:id="ms002_I-Vlevi_CF.C.9_d001_p001"       n="1"
                      (id of the nearest enclosing div + _p###)
    pb                xml:id="ms002_I-Vlevi_CF.C.9_pb001"
                      (existing @n and @facs are kept)
    notatedMusic      xml:id="ms002_I-Vlevi_CF.C.9_m001"            n="1"
    notatedMusic/graphic is replaced by
                      <ptr target="ms002_I-Vlevi_CF.C.9_m001.xml"/>

  NUMBERING RULES
    - Top-level divs, pb and notatedMusic are counted across the whole
      body in document order.
    - Nested divs are counted within their parent div.
    - p elements are counted within their nearest enclosing div (or within
      the body if they have no enclosing div).
    - @n always carries the same running number as the xml:id suffix.
    - Existing @xml:id / @n on these elements are REPLACED (never duplicated).

  REUSE
    Only the CONFIGURATION section below needs to be touched. By default the
    ID prefix is derived automatically from the file name of the source
    document (e.g. "ms002_I-Vlevi_CF.C.9.xml" -> "ms002_I-Vlevi_CF.C.9"), so
    the stylesheet can be applied to any transcription without changes.
    To force a specific prefix, set the parameter "manualPrefix" (either in
    this file or as a transformation parameter, e.g. in Oxygen or Saxon:
    manualPrefix=ms002_I-Vlevi_CF.C.9).

  REQUIREMENTS
    XSLT 2.0 processor (e.g. Saxon HE/PE/EE, as used by Oxygen XML Editor).
  ==========================================================================
-->
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:f="urn:local:xml-ids:functions"
    exclude-result-prefixes="#all">

    <!-- ====================================================================
         OUTPUT SETTINGS
         indent="no" keeps the whitespace/layout of the source exactly as it
         is; the XML declaration is written with UTF-8 encoding.
         ==================================================================== -->
    <xsl:output method="xml" encoding="UTF-8" indent="no"/>


    <!-- ====================================================================
         CONFIGURATION (the only section to adapt for other documents)
         ==================================================================== -->

    <!-- Manual ID prefix. Leave empty ('') to derive the prefix from the
         source file name. Example of a fixed value:
         <xsl:param name="manualPrefix" select="'ms002_I-Vlevi_CF.C.9'"/> -->
    <xsl:param name="manualPrefix" as="xs:string" select="''"/>

    <!-- Separator between the parts of an ID. -->
    <xsl:variable name="sep" as="xs:string" select="'_'"/>

    <!-- Type markers used in the IDs for each kind of element. -->
    <xsl:variable name="divMarker"          as="xs:string" select="'d'"/>
    <xsl:variable name="subDivMarker"       as="xs:string" select="'sd'"/>
    <xsl:variable name="pMarker"            as="xs:string" select="'p'"/>
    <xsl:variable name="pbMarker"           as="xs:string" select="'pb'"/>
    <xsl:variable name="notatedMusicMarker" as="xs:string" select="'m'"/>

    <!-- Number picture: '000' produces three digits with leading zeros
         (1 -> 001). Use e.g. '0000' for four digits. -->
    <xsl:variable name="numberFormat" as="xs:string" select="'000'"/>

    <!-- File extension appended to the notatedMusic ID in ptr/@target. -->
    <xsl:variable name="musicFileExtension" as="xs:string" select="'.xml'"/>


    <!-- ====================================================================
         DERIVED VARIABLES (normally no need to change)
         ==================================================================== -->

    <!-- File name of the source document without directory and without the
         ".xml" extension, e.g. "ms002_I-Vlevi_CF.C.9". -->
    <xsl:variable name="fileNamePrefix" as="xs:string"
        select="replace(tokenize(string(base-uri(/)), '/')[last()], '\.xml$', '', 'i')"/>

    <!-- The constant part of every generated ID: the manual prefix if one
         is given, otherwise the prefix derived from the file name. -->
    <xsl:variable name="idPrefix" as="xs:string"
        select="if (normalize-space($manualPrefix) != '')
                then normalize-space($manualPrefix)
                else $fileNamePrefix"/>


    <!-- ====================================================================
         KEYS
         Used to count elements relative to their "container".
         ==================================================================== -->

    <!-- Groups every div in the body by its nearest enclosing div (for
         top-level divs the container is the body itself). -->
    <xsl:key name="divsByContainer"
        match="tei:body//tei:div"
        use="generate-id((ancestor::tei:div[1], ancestor::tei:body[1])[1])"/>

    <!-- Groups every p in the body by its nearest enclosing div (or the body
         if there is no enclosing div). -->
    <xsl:key name="psByContainer"
        match="tei:body//tei:p"
        use="generate-id((ancestor::tei:div[1], ancestor::tei:body[1])[1])"/>


    <!-- ====================================================================
         FUNCTIONS
         ==================================================================== -->

    <!-- Returns the running number of a node within a sequence of nodes
         (the sequence must be in document order, as returned by key()). -->
    <xsl:function name="f:position-in" as="xs:integer">
        <xsl:param name="node" as="node()"/>
        <xsl:param name="sequence" as="node()*"/>
        <xsl:sequence select="count($sequence[. &lt;&lt; $node]) + 1"/>
    </xsl:function>

    <!-- Returns the container (nearest enclosing div or the body) used for
         counting a div or p. -->
    <xsl:function name="f:container" as="element()">
        <xsl:param name="node" as="element()"/>
        <xsl:sequence select="($node/ancestor::tei:div[1], $node/ancestor::tei:body[1])[1]"/>
    </xsl:function>

    <!-- Running number of a div within its container (parent div or body). -->
    <xsl:function name="f:div-number" as="xs:integer">
        <xsl:param name="div" as="element(tei:div)"/>
        <xsl:sequence select="f:position-in($div,
            key('divsByContainer', generate-id(f:container($div)), root($div)))"/>
    </xsl:function>

    <!-- Builds the xml:id of a div recursively:
         - a top-level div gets  <prefix>_d###
         - a nested div gets     <id of parent div>_sd###          -->
    <xsl:function name="f:div-id" as="xs:string">
        <xsl:param name="div" as="element(tei:div)"/>
        <xsl:variable name="num" as="xs:string"
            select="format-number(f:div-number($div), $numberFormat)"/>
        <xsl:sequence select="
            if ($div/ancestor::tei:div)
            then concat(f:div-id($div/ancestor::tei:div[1]), $sep, $subDivMarker, $num)
            else concat($idPrefix, $sep, $divMarker, $num)"/>
    </xsl:function>

    <!-- Running number of a notatedMusic element in the whole body. -->
    <xsl:function name="f:music-number" as="xs:integer">
        <xsl:param name="music" as="element(tei:notatedMusic)"/>
        <xsl:sequence select="count($music/preceding::tei:notatedMusic[ancestor::tei:body]) + 1"/>
    </xsl:function>

    <!-- Builds the xml:id of a notatedMusic element: <prefix>_m### -->
    <xsl:function name="f:music-id" as="xs:string">
        <xsl:param name="music" as="element(tei:notatedMusic)"/>
        <xsl:sequence select="concat($idPrefix, $sep, $notatedMusicMarker,
            format-number(f:music-number($music), $numberFormat))"/>
    </xsl:function>


    <!-- ====================================================================
         TEMPLATE 1: IDENTITY TRANSFORMATION
         Copies every node (elements, attributes, text, comments, processing
         instructions) unchanged. xsl:copy only copies the namespaces that
         are already present on the source element, and exclude-result-
         prefixes="#all" prevents the stylesheet's own namespace
         declarations (xsl, xs, tei prefix) from appearing in the output.
         ==================================================================== -->
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>


    <!-- ====================================================================
         TEMPLATE 1b: DOCUMENT NODE
         Writes a line break after the XML declaration (as in the source)
         and then processes the document content with the identity rule.
         ==================================================================== -->
    <xsl:template match="/">
        <xsl:text>&#10;</xsl:text>
        <xsl:apply-templates select="node()"/>
    </xsl:template>


    <!-- ====================================================================
         TEMPLATE 2: div ELEMENTS IN THE BODY
         1. Copy the element itself.
         2. Add the generated xml:id (d### or <parent>_sd###).
         3. Add @n with the running number within the container.
         4. Copy all other existing attributes (an old xml:id or n is
            dropped so that it is not duplicated).
         5. Process the content (nested divs, p, pb, ... are handled by
            their own templates).
         ==================================================================== -->
    <xsl:template match="tei:body//tei:div">
        <xsl:copy>
            <xsl:attribute name="xml:id" select="f:div-id(.)"/>
            <xsl:attribute name="n" select="f:div-number(.)"/>
            <xsl:apply-templates select="@*[not(name() = ('xml:id', 'n'))]"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>


    <!-- ====================================================================
         TEMPLATE 3: p ELEMENTS IN THE BODY
         1. Determine the container (nearest enclosing div, else body).
         2. Determine the running number of the p within that container.
         3. Build the ID: <id of container div>_p###
            (if the p is not inside any div: <prefix>_p###).
         4. Add xml:id and n, copy all other attributes, process content.
         ==================================================================== -->
    <xsl:template match="tei:body//tei:p">
        <xsl:variable name="container" as="element()" select="f:container(.)"/>
        <xsl:variable name="num" as="xs:integer"
            select="f:position-in(., key('psByContainer', generate-id($container)))"/>
        <xsl:variable name="baseId" as="xs:string"
            select="if ($container/self::tei:div) then f:div-id($container) else $idPrefix"/>
        <xsl:copy>
            <xsl:attribute name="xml:id"
                select="concat($baseId, $sep, $pMarker, format-number($num, $numberFormat))"/>
            <xsl:attribute name="n" select="$num"/>
            <xsl:apply-templates select="@*[not(name() = ('xml:id', 'n'))]"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>


    <!-- ====================================================================
         TEMPLATE 4: pb ELEMENTS IN THE BODY
         1. Count all preceding pb elements in the body (+1) to obtain the
            running number in document order.
         2. Copy all existing attributes except an old xml:id (e.g.
            "img_0001"), which is replaced by the new one.
         3. Add the new ID: <prefix>_pb###
         ==================================================================== -->
    <xsl:template match="tei:body//tei:pb">
        <xsl:variable name="num" as="xs:integer"
            select="count(preceding::tei:pb[ancestor::tei:body]) + 1"/>
        <xsl:copy>
            <xsl:apply-templates select="@*[not(name() = 'xml:id')]"/>
            <xsl:attribute name="xml:id"
                select="concat($idPrefix, $sep, $pbMarker, format-number($num, $numberFormat))"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>


    <!-- ====================================================================
         TEMPLATE 5: notatedMusic ELEMENTS IN THE BODY
         1. Add the generated ID <prefix>_m### and @n with the running
            number in document order across the whole body.
         2. Copy all other existing attributes (e.g. @facs, @type).
         3. Process the content; graphic children are converted to ptr by
            template 6.
         ==================================================================== -->
    <xsl:template match="tei:body//tei:notatedMusic">
        <xsl:copy>
            <xsl:attribute name="xml:id" select="f:music-id(.)"/>
            <xsl:attribute name="n" select="f:music-number(.)"/>
            <xsl:apply-templates select="@*[not(name() = ('xml:id', 'n'))]"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>


    <!-- ====================================================================
         TEMPLATE 6: graphic CHILDREN OF notatedMusic IN THE BODY
         Replaces <graphic url="..."/> by
         <ptr target="<xml:id of parent notatedMusic>.xml"/>.
         The ptr element is created in the same namespace as the graphic
         element (TEI), so no new namespace declaration is produced. The old
         @url (placeholder "example.xml") is intentionally not copied.
         ==================================================================== -->
    <xsl:template match="tei:body//tei:notatedMusic/tei:graphic">
        <xsl:element name="ptr" namespace="{namespace-uri()}">
            <xsl:attribute name="target"
                select="concat(f:music-id(parent::tei:notatedMusic), $musicFileExtension)"/>
        </xsl:element>
    </xsl:template>

</xsl:stylesheet>
