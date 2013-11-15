#!/usr/bin/perl -w
#@----------------------------------------------------------------------------------------------------------------------
#@ Copyright 2012 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ This script creates lists of CMDI files and stores it in an XML for processing by an XSLT for each CMDI profile.
#@ It reads and creates a list of CMDI files, extract all profiles.
#@ Two step approach:
#@   1) create a file list per profile 
#@   2) append XML prolog and root tags
#@----------------------------------------------------------------------------------------------------------------------
use IndexCMDI; # plugin reference to Package file

# creating a new object of class IndexCMDI
my $object = new IndexCMDI();

#---------------------------------------------------------------------------------------------
# set up the correct directory with CMDI files, set up the correct directory with CMDI files
#---------------------------------------------------------------------------------------------
my @files = $object->read_files_from_dir("../data2/cmdi/*/*.xml");

#-------------------------------------
# hash with XML schemas 
#-------------------------------------
my %xmlSchemas = ();

#-------------------------------------
# directory for temporary list 
#-------------------------------------
$object->reset_dir("indexListTmp");

#-----------------------
# extract the profiles
#-----------------------
foreach my $file (@files) 
{
	if($file !~ /_corpusstructure/) 
	{
 		open(FILE, "<$file") or die("Could not open $file: $!");
 		while(<FILE>) 
 		{
 			if($_ =~ /\s+xsi:schemaLocation=\".*\s*(http.+)\"/) 
 			{
 				my $schema = $1;

				# do not process potential unknown and problematic schemas
 				if($schema =~ /xsd$/) 
 				{
					$xmlSchemas{$schema}++;

          my $outFile = $object->extract_xml_schema_clean($xmlSchema);
					$outFile = "indexListTmp/" . $outFile . ".xml";

					open(OUT, ">> $outFile") or die("Could not open $outFile, $!");
					print OUT "<doc href=\"../$file\"/>";
					close(OUT);

					next;
				}
 			}
 		}
 		close(FILE);
	}
}

#-------------------------------------
# directory for files with lists 
#-------------------------------------
$object->reset_dir("indexList");

#-------------------------------------
# append XML prolog and root tags
#-------------------------------------
my @outFiles = $object->read_files_from_dir("indexListTmp/*.xml");

foreach my $file (@outFiles) 
{
	open(FILE, "<$file") or die("Could not open $file: $!");

	my $outFile = $file;
	$outFile =~ s/indexListTmp\/(.+)/$1/;
	$outFile = "indexList/" . $outFile;

	open(OUT, "> $outFile") or die("Could not open $outFile: $!");
	print OUT "<?xml version=\"1.0\" encoding=\"utf-8\"?><collection>";
	while(<FILE>) 
	{
		print OUT "$_";
	}
	print OUT "</collection>";
	close(OUT);

	close(FILE);
}

#-------------------------------------------
# extract XML schemas from the Web service
#-------------------------------------------
open(FILE, "> schemas.tmp") or die("Could not open schemas.tmp: $!");
foreach my $schema (keys %xmlSchemas) 
{
	print FILE "$schema\n";
}
close(FILE);