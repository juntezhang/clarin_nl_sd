#!/usr/bin/perl -w
#@--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#@ By Junte Zhang <juntezhang@gmail.com> in 2013
#@ Distributed under the GNU General Public Licence
#@
#@ This script generates separate XML index files for Lucene based on pairs of XSLT and XML files consisting of lists for each CMDI schema
#@---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
use IndexCMDI; # plugin reference to Package file

# path to the Saxon parser
my $saxon = "/Software/saxonb9-1-0-8j/saxon9.jar";

# creating a new object of class IndexCMDI
my $object = new IndexCMDI();

# extract multiple XML schemas
my %xmlSchemas = $object->store_xml_schemas_in_hash("schemasNames.tmp");

# 1) XSLT for clean-up pre-process step
$object->reset_dir("preprocessXSL");

# 2) directory with output of 1)
$object->reset_dir("indexDataCleaned");

# 3) directory with index files
$object->reset_dir("indexData");

# 4) create Solr index files per profile, note that the XSLT to do the "wrangling" has previously been created in cmdi-xsl-per-schema.pl
foreach my $schema (keys %xmlSchemas) 
{
  my $outFile = $object->extract_xml_schema_clean($schema);

	my $outFileXML = $outFile . ".xml";
	my $outFileXSL = $outFile . ".xsl";

	# create pre-process XSLT file
	open(XSL, "> preprocessXSL/$outFileXSL") or die("Could not open $outFileXSL, $!");
	print XSL '<xsl:stylesheet version="2.0"
	xmlns:saxon="http://saxon.sf.net/"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
		<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="no"/>
	<xsl:strip-space elements="*"/>
<!--
	preprocess-cdmi.xsl: this script cleans up the CMDI files and creates a data file
-->

<!-- Loop through all CMDI files -->
	<xsl:template match="/">
		<add>
		<!-- going through each file -->
		<xsl:for-each select="collection(\'../indexList/' . $outFileXML . '\')">
			<xsl:apply-templates />
		</xsl:for-each>
		</add>
	</xsl:template>

<!-- Removing element prefixes -->
	<xsl:template match="*">
		<!-- remove element prefix -->
		<xsl:element name="{local-name()}">
			<!-- process attributes -->
			<xsl:for-each select="@*">
				<!-- remove attribute prefix -->
				<xsl:attribute name="{local-name()}">
					<xsl:value-of select="normalize-space(.)"/>
				</xsl:attribute>
			</xsl:for-each>
			<xsl:apply-templates/>
		</xsl:element>
	</xsl:template>

<!-- Removing empty elements -->
	<xsl:template match="*[. = \'\' or . = \'-1\']"/>

<!-- Remove redundant elements when parent is equal to child -->
  <xsl:template match="*[name()=name(*[1])]">
      <xsl:apply-templates/>
  </xsl:template>
    
	<xsl:template match="text()">
		<xsl:text> </xsl:text>
		<xsl:value-of select="normalize-space(.)" />
		<xsl:text> </xsl:text>
	</xsl:template>
</xsl:stylesheet>';
	close(XSL);

	# create cleaned-up files
	system("java -Xmx2g -jar $saxon -warnings:silent indexList/$outFileXML preprocessXSL/$outFileXSL > indexDataCleaned/$outFileXML");

	# create index data files from cleaned-up files
	system("java -Xmx2g -jar $saxon -warnings:silent indexDataCleaned/$outFileXML indexSchemas/$outFileXSL > indexData/$outFileXML");	
}







