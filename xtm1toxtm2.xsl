<!--  XTM 1.0 to XTM 2.0 converter

  @author Alexander Mikhailian <ami at spaceapplications.com>

This is an XSLT 1.0 stylesheet to convert from XTM 1.0 to XTM 2.0.

The input should conform to the XTM 1.0 DTD 
  http://www.topicmaps.org/xtm/

The output attempts to conforms to the XTM 2.0 RelaxNG
  http://www.isotopicmaps.org/sam/sam-xtm/2006-06-19/

Since the automatic conversion is not always possible, the converter may try to
coerce the input or bail out.

If running with xsltproc, check the error return value to see if the conversion
succeedes, e.g.:

  find . -name  '*xtm'|while read xtm
  do
    xsltproc xtm1toxtm2.xsl "$xtm" > ${xtm%xtm}xtm2
    if [ $? -eq 0 ]; then
      echo "$xtm passed."
    else
      echo "$xtm failed."
      rm ${xtm%xtm}xtm2
    fi
  done

See around the lines starting with <xsl:message for possible failure reasons.

This stylesheet does no validation of the contents of the href attribute. 

This stylesheet attempts to preserve the reifiers of topic map constructs
that use URI fragments That is, internal to the topic map only.

Copyright (c) 2007, Space Applications Services
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Space Applications Services nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY SPACE APPLICATIONS SERVICES ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SPACE APPLICATIONS SERVICES BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl="http://exslt.org/common"
    exclude-result-prefixes="exsl"
    version="1.0"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:tm1="http://www.topicmaps.org/xtm/1.0/"
    xmlns:tm2="http://www.topicmaps.org/xtm/">

  <xsl:output method="xml"
              version="1.0"
              indent="yes"/>

  <xsl:key name="reifier" 
    match="tm1:topic" 
    use="tm1:subjectIdentity/tm1:subjectIndicatorRef/@xlink:href"/>

  <xsl:key name="reifiable" 
    match="tm1:*" 
    use="@id"/>

  <!-- copy and change the namespace from tm1 to tm2-->
  <xsl:template match="tm1:*" >
    <xsl:element name="{local-name()}" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- add the version attribute to the topicMap element -->
  <!--drop the xml:base attribute -->
  <!--the order of elements below topicMap has changed -->
  <xsl:template match="tm1:topicMap">
    <xsl:element name="topicMap" namespace="http://www.topicmaps.org/xtm/">
      <xsl:attribute name="version">2.0</xsl:attribute>
      <!-- reification -->
      <xsl:if test="@id">
        <xsl:call-template name="reification">
          <xsl:with-param name="reifiers"> <xsl:copy-of select="key('reifier', concat('#',@id))"/></xsl:with-param>
        </xsl:call-template>
        <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
          <xsl:attribute name="href">
           <xsl:value-of select="concat('#',@id)"/>
          </xsl:attribute>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates select="tm1:mergeMap"/>
      <xsl:apply-templates select="tm1:topic | tm1:association"/>
    </xsl:element>
  </xsl:template>


  <!-- mergeMap contains only a @href now-->
  <xsl:template match="tm1:mergeMap">
    <xsl:element name="mergeMap" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@xlink:href"/>
    </xsl:element>
  </xsl:template>

  <!-- rename xlink:href to href attribute-->
  <!-- this can fail as CDATA in the XTM 1.0 
       DTD is less restrictive than anyURI in 
       the XTM 2.0 RNG -->
  <xsl:template match="@xlink:href">
    <xsl:attribute name="href"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!--drop the @id everywhere except topic-->
  <xsl:template match="@id">
    <xsl:if test="parent::tm1:topic">
      <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!--add the version attribute to the topicMap-->
  <xsl:template match="topicMap">
    <xsl:attribute name="version">
      <xsl:value-of select="2.0" />
    </xsl:attribute>
    <xsl:apply-templates select="@*" />
    <xsl:apply-templates/>
  </xsl:template>

  <!--instanceOf -> type everywhere except the topic -->
  <!--instanceOf* -> instanceOf? under topic  -->
  <xsl:template match="tm1:instanceOf">
    <xsl:choose>
      <xsl:when test="preceding-sibling::tm1:instanceOf">
        <!--  The tm1:topic template further down this script makes an 
        association element out of it. -->
      </xsl:when>
      <xsl:when test="parent::tm1:topic">
        <xsl:element name="instanceOf" namespace="http://www.topicmaps.org/xtm/">
          <xsl:apply-templates select="@*" />
          <xsl:apply-templates/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="type" namespace="http://www.topicmaps.org/xtm/">
          <xsl:apply-templates select="@*" />
          <xsl:apply-templates/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--parameters -> scope -->
  <xsl:template match="tm1:parameters">
    <xsl:element name="scope" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!--roleSpec -> type -->
  <xsl:template match="tm1:roleSpec">
    <xsl:element name="type" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!--baseName -> name -->
  <xsl:template match="tm1:baseName">
    <xsl:element name="name" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:if test="@id">
        <xsl:call-template name="reification">
          <xsl:with-param name="reifiers"> <xsl:copy-of select="key('reifier', concat('#',@id))"/></xsl:with-param>
        </xsl:call-template>
        <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
          <xsl:attribute name="href">
            <xsl:value-of select="concat('#',@id)"/>
          </xsl:attribute>
        </xsl:element>
       </xsl:if>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!--baseNameString -> value -->
  <xsl:template match="tm1:baseNameString">
    <xsl:element name="value" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!--variantName -> :nil -->
  <xsl:template match="tm1:variantName">
    <xsl:apply-templates/>
  </xsl:template>

  <!--subjectIdentity -> :nil -->
  <xsl:template match="tm1:subjectIdentity">
    <xsl:apply-templates select="@*" />
    <xsl:apply-templates/>
    <!-- reification of topic maps constructs -->
    <!--xsl:if test="starts-with(tm1:subjectIndicatorRef/@xlink:href, '#')">
      <xsl:for-each select="key('reifiable', substring-after(tm1:subjectIndicatorRef/@xlink:href, '#'))">
        <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
          <xsl:attribute name="href"><xsl:value-of select="concat('#', @id)"/></xsl:attribute>
        </xsl:element>
      </xsl:for-each>
    </xsl:if-->
  </xsl:template>

  <!--member -> role -->
  <xsl:template match="tm1:member">
    <xsl:element name="role" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:if test="@id">
        <xsl:call-template name="reification">
          <xsl:with-param name="reifiers"> <xsl:copy-of select="key('reifier', concat('#',@id))"/></xsl:with-param>
        </xsl:call-template>
        <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
          <xsl:attribute name="href">
            <xsl:value-of select="concat('#',@id)"/>
          </xsl:attribute>
        </xsl:element>
       </xsl:if>
      <!--the type is required -->
      <xsl:if test="count(tm1:roleSpec) = 0">
        <xsl:message terminate="yes">No type found for the role, terminating.</xsl:message>
        <!--TODO use the default type, but which one? -->
      </xsl:if>
      <xsl:apply-templates select="tm1:roleSpec"/>
      <!--one topic reference is required per role -->
      <xsl:choose>
        <xsl:when test="count(tm1:topicRef) =  0">
          <xsl:message terminate="yes">No player found for the role, terminating.</xsl:message>
          <!--TODO use the default topicRef, but which one? -->
        </xsl:when>
        <xsl:when test="count(tm1:topicRef) =  1">
          <xsl:apply-templates select="tm1:topicRef"/>
        </xsl:when>
        <xsl:when test="count(tm1:topicRef) >  1">
          <!--Many players exist for the role, converting the first,
            will generate new roles for each next player later. -->
          <xsl:apply-templates select="tm1:topicRef[1]"/>
        </xsl:when>
      </xsl:choose>
      <xsl:apply-templates select="tm1:resourceRef | tm1:subjectIndicatorRef"/>
    </xsl:element>
    <xsl:apply-templates select="tm1:topicRef[position() > 1]" mode="new-role"/>
  </xsl:template>

  <!-- create new roles if many players in tm1:member -->
  <xsl:template match="tm1:topicRef" mode="new-role">
    <xsl:element name="role" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="parent::tm1:member/tm1:roleSpec"/>
      <xsl:apply-templates select="."/>
  </xsl:element>
  </xsl:template>

  <!-- variant names can not be nested -->
  <xsl:template match="tm1:variant">
    <xsl:choose>
      <xsl:when test="parent::tm1:variant">
        <xsl:message terminate="no">Dropping the nested variant name instead of attemping a recovery.</xsl:message>
        <!--TODO none uses them anyway -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="variant"  namespace="http://www.topicmaps.org/xtm/">
          <xsl:apply-templates select="@*" />
          <xsl:if test="@id">
            <xsl:call-template name="reification">
              <xsl:with-param name="reifiers"> <xsl:copy-of select="key('reifier', concat('#',@id))"/></xsl:with-param>
            </xsl:call-template>
            <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
              <xsl:attribute name="href">
                <xsl:value-of select="concat('#',@id)"/>
              </xsl:attribute>
            </xsl:element>
          </xsl:if>
          <xsl:apply-templates/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- occurrence should have a type -->
  <xsl:template match="tm1:occurrence">
    <xsl:if test="count(tm1:instanceOf) = 0">
      <xsl:message terminate="yes">No type found for the occurrence, terminating.</xsl:message>
      <!--TODO use the default type, but which one?-->
    </xsl:if>
    <xsl:element name="occurrence" namespace="http://www.topicmaps.org/xtm/">
      <!-- reification -->
      <xsl:if test="@id">
        <xsl:call-template name="reification">
          <xsl:with-param name="reifiers"> <xsl:copy-of select="key('reifier', concat('#',@id))"/></xsl:with-param>
        </xsl:call-template>
        <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
          <xsl:attribute name="href">
            <xsl:value-of select="concat('#',@id)"/>
          </xsl:attribute>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- association should have a type -->
  <xsl:template match="tm1:association">
    <xsl:if test="count(tm1:instanceOf) = 0">
      <xsl:message terminate="yes">No type found for the association, terminating.</xsl:message>
      <!--TODO use the default type, but which one? -->
    </xsl:if>
    <xsl:element name="association" namespace="http://www.topicmaps.org/xtm/">
      <!-- reification -->
      <xsl:if test="@id">
        <xsl:call-template name="reification">
          <xsl:with-param name="reifiers"> <xsl:copy-of select="key('reifier', concat('#',@id))"/></xsl:with-param>
        </xsl:call-template>
        <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
          <xsl:attribute name="href">
            <xsl:value-of select="concat('#',@id)"/>
          </xsl:attribute>
        </xsl:element>
       </xsl:if>
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>


  <!-- subjectIdentity/subjectIndicatorRef -> subjectIdentifier -->
  <xsl:template match="tm1:subjectIdentity/tm1:subjectIndicatorRef">
    <xsl:element name="subjectIdentifier" namespace="http://www.topicmaps.org/xtm/">
      <!-- renaming some of the association types and role types-->
      <xsl:choose>

        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#topic'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/glossary/topic</xsl:attribute>
        </xsl:when>

        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#association'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/glossary/association</xsl:attribute>
        </xsl:when>

        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#occurrence'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/glossary/occurrence</xsl:attribute>
        </xsl:when>

        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#class-instance'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/type-instance</xsl:attribute>
        </xsl:when>
        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#class'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/type</xsl:attribute>
        </xsl:when>
        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#instance'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/instance</xsl:attribute>
        </xsl:when>

        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#superclass-subclass'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/supertype-subtype</xsl:attribute>
        </xsl:when>
        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#superclass'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/supertype</xsl:attribute>
        </xsl:when>
        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#subclass'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/subtype</xsl:attribute>
        </xsl:when>

        <xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#sort'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/model/sort</xsl:attribute>
        </xsl:when>

        <!--xsl:when test="@xlink:href='http://www.topicmaps.org/xtm/1.0/core.xtm#display'">
          <xsl:attribute name="href">http://psi.topicmaps.org/iso13250/glossary/???</xsl:attribute>
        </xsl:when-->

        <xsl:otherwise>
          <xsl:apply-templates select="@xlink:href"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- subjectIdentity/resourceRef -> subjectLocator -->
  <xsl:template match="tm1:subjectIdentity/tm1:resourceRef">
    <xsl:element name="subjectLocator" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@xlink:href"/>
    </xsl:element>
  </xsl:template>

  <!-- subjectIdentity/topicRef -> itemIdentity -->
  <xsl:template match="tm1:subjectIdentity/tm1:topicRef">
    <xsl:element name="itemIdentity" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@xlink:href"/>
    </xsl:element>
  </xsl:template>

  <!--the order of topic children has changed, reorder the processing accordingly -->
  <xsl:template match="tm1:topic">
    <xsl:element name="topic" namespace="http://www.topicmaps.org/xtm/">
      <xsl:apply-templates select="@*" />
      <xsl:apply-templates select="tm1:subjectIdentity" />
      <xsl:apply-templates select="tm1:instanceOf" />
      <xsl:apply-templates select="tm1:baseName" />
      <xsl:apply-templates select="tm1:occurrence" />
    </xsl:element>
    <!--make new associations if multiple instanceOf are detected -->
    <xsl:for-each select="tm1:instanceOf[preceding-sibling::tm1:instanceOf]">
      <xsl:element name="association" namespace="http://www.topicmaps.org/xtm/">
        <xsl:element name="type" namespace="http://www.topicmaps.org/xtm/">
          <xsl:element name="topicRef" namespace="http://www.topicmaps.org/xtm/">
            <xsl:attribute name="href"><xsl:value-of select="'#type-instance'"/></xsl:attribute>
          </xsl:element>
        </xsl:element>
        <xsl:element name="role" namespace="http://www.topicmaps.org/xtm/">
          <!-- type 1 -->
          <xsl:element name="type" namespace="http://www.topicmaps.org/xtm/">
            <xsl:element name="topicRef" namespace="http://www.topicmaps.org/xtm/">
              <xsl:attribute name="href"><xsl:value-of select="'#type'"/></xsl:attribute>
            </xsl:element>
          </xsl:element>
          <!-- player 1 -->
          <xsl:element name="topicRef" namespace="http://www.topicmaps.org/xtm/">
            <xsl:attribute name="href"><xsl:value-of select="tm1:topicRef/@xlink:href"/></xsl:attribute>
          </xsl:element>
        </xsl:element>
        <xsl:element name="role" namespace="http://www.topicmaps.org/xtm/">
          <!-- type 2 -->
          <xsl:element name="type" namespace="http://www.topicmaps.org/xtm/">
            <xsl:element name="topicRef" namespace="http://www.topicmaps.org/xtm/">
              <xsl:attribute name="href"><xsl:value-of select="'#instance'"/></xsl:attribute>
            </xsl:element>
          </xsl:element>
            <!-- player 2 -->
          <xsl:element name="topicRef" namespace="http://www.topicmaps.org/xtm/">
            <xsl:attribute name="href">#<xsl:value-of select="parent::*/@id"/></xsl:attribute>
          </xsl:element>
        </xsl:element>
      </xsl:element>
    </xsl:for-each>
  </xsl:template>

<!-- helpers -->

<xsl:template name="reification">
    <xsl:param name="reifiers"/>
    <xsl:choose>
      <xsl:when test="count($reifiers) = 0 or string-length($reifiers) = 0" >
      </xsl:when>
      <xsl:when test="count($reifiers) = 1">
        <xsl:attribute name="reifier"><xsl:value-of select="concat('#', exsl:node-set($reifiers)/tm1:topic[1]/@id)"/></xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">More than one reifier found, terminating instead of merging.</xsl:message>
        <!--TODO merge the reifiers together -->
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
