#!/usr/bin/perl -w
#@-------------------------------------------------------------------------------
#@ Copyright 2012 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ This script generates XSLT on-the-fly to map CMDI files to Solr XML format
#@-------------------------------------------------------------------------------
use IndexCMDI; # plugin reference to Package file
use Data::Dumper;

# creating a new object of class IndexCMDI
my $object = new IndexCMDI();

# extract multiple XML schemas
my %xmlSchemas = $object->store_xml_schemas_in_hash("schemasNames.tmp");

# store all schema names by XML schema/CMDI profile
my %schemaNames = $object->store_schema_names_in_hash("schemasNames.tmp");

# 1) CSV from schema parser
$object->reset_dir("mapping");

# 2) directory with XSLTs to generate Solr index files 
$object->reset_dir("indexSchemas");

# extract XML schemas from the Web service
foreach my $schema (keys %xmlSchemas) 
{
  $object->extract_xsl("$schema");
}

$object->extract_xsl_all();

