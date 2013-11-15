#!/usr/bin/perl -w
#@--------------------------------------------------------------------------
#@ Copyright 2012 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ This script creates a Solr schema.xml file
#@--------------------------------------------------------------------------
use IndexCMDI; # plugin reference to Package file
use Data::Dumper;

# creating a new object of class IndexCMDI
my $object = new IndexCMDI();

# extract multiple XML schemas
my %xmlSchemas = $object->store_xml_schemas_in_hash("schemasNames.tmp");

# store the ISOcat mapping in a global hash
my %lookupTable = ();

# extract XML schemas from the Web service
foreach my $schema (keys %xmlSchemas) {
	#print "$schema\n";
	$object->extract_labels("$schema");
}

# print out for solrconfig.xml for caching
$object->print_solr_cache_labels("solrconfig_part.xml");

# print out for cmdi.labels.js
$object->print_ajax_solr_labels();



