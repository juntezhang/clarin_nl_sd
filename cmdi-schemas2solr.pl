#!/usr/bin/perl -w
#@--------------------------------------------------------------------------
#@ Copyright 2012 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ This script creates a Solr schema.xml file from multiple XML schemas
#@--------------------------------------------------------------------------
use IndexCMDI; # plugin reference to Package file
use Data::Dumper;

# creating a new object of class IndexCMDI
my $object = new IndexCMDI();

# extract multiple XML schemas
my %xmlSchemas = $object->store_xml_schemas_in_hash("schemasNames.tmp");

# store all schema names by XML schema/CMDI profile
my %schemaNames = $object->store_schema_names_in_hash("schemasNames.tmp");

# extract schema information to a global hash
foreach my $schema (keys %xmlSchemas) {
	$object->extract_schema_to_hash($schema);
}

# create the new schema.xml
$object->create_new_solr_schema("dummy-schema2.xml", );
