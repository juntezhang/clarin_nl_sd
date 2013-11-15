#!/usr/bin/perl -w
#@-----------------------------------------------------------------------------
#@ Copyright 2013 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ IndexCMDI class for the CMDI MI indexing process 
#@-----------------------------------------------------------------------------
package IndexCMDI;

use strict;
use warnings;

use WWW::Curl::Easy;
use Data::Dump qw(dump);

#------------------------------------------------------------------------------
# store the ISOcat mapping in a global hash (i.e. can be used in whole script)
#------------------------------------------------------------------------------
my ( $file, %xmlSchemas, %schemaNames, %lookupTableGlob, %lookup_table_labels  );

sub new 
{
  my ($class, %args) = @_;  
  return bless { %args }, $class;
}

#--------------------------------------------------
# subroutine to reset a directory of output files
# In  : name of output directory
# Out : none
#--------------------------------------------------
sub reset_dir 
{
  my ( $self, $dir ) = @_;
  if(-e "$dir") 
  {
    system("rm -rf $dir");
    system("mkdir $dir");
  }
  else 
  {
    system("mkdir $dir");
  }
}

#-------------------------------------------------------
# subroutine to check if directory exists, and if not, create it
# In  : scalar variable with dir name
# Out : if exists, then do nothing, else create it
#-------------------------------------------------------
sub check_not_dir
{
  my ( $self, $dir ) = @_;

  unless(-e "$dir") 
  {
    system("mkdir $dir");
  }  
}

#----------------------------------------------
# subroutine to get the XML schemas 
# In  : file with table with XML schema
# Out : hash with XML schema
#----------------------------------------------
sub store_xml_schemas_in_hash 
{
  my ( $self, $file ) = @_;

  my %xmlSchemas = ();
  open(FILE, "<", $file) or die("Could not open $file: $!");
  while(<FILE>) {
    $_ =~ s/\R//g;
    if($_ =~ /(.+)\s+(.+)/) {
      $xmlSchemas{"$1"}++;
      $schemaNames{"$1"} = $2;
    }
  }
  close(FILE);  

  return %xmlSchemas;
}

#----------------------------------------------
# subroutine to get the schema names
# In  : file with table with schema names
# Out : hash with schema names
#----------------------------------------------
sub store_schema_names_in_hash 
{
  my ( $self, $file ) = @_;

  my %schemaNames = ();
  open(FILE, "<", $file) or die("Could not open $file: $!");
  while(<FILE>) {
    $_ =~ s/\R//g;
    if($_ =~ /(.+)\s+(.+)/) {
      $xmlSchemas{"$1"}++;
      $schemaNames{"$1"} = $2;
    }
  }
  close(FILE);  

  return %schemaNames;
}

#----------------------------------------------
# subroutine to generate the XSLTs
# In  : XML schema reference
# Out : XSLT files
#----------------------------------------------
sub extract_xsl
{
	my ( $self, $xmlSchema ) = @_;

	my $curl_cache = WWW::Curl::Easy->new({timeout => '999999999'});
	my $curl = WWW::Curl::Easy->new({timeout => '999999999'});

	my @authHeader = ('Accept: text/csv', 'Content-Type: text/csv');

	my $outFile = extract_xml_schema_clean(undef, $xmlSchema);

	my $lookupFile = $outFile; 

	$outFile = "indexSchemas/" . $outFile . ".xsl";
	check_not_dir(undef, "indexSchemas"); 

	my %lookupTable = ();

	my $url = "http://yago.meertens.knaw.nl/SchemaParser/indexTypes?schemaReference=" . $xmlSchema;

	# clear cache first
	$curl_cache->setopt(CURLOPT_HEADER,0);
	$curl_cache->setopt(CURLOPT_HTTPHEADER,\@authHeader);
	$curl_cache->setopt(CURLOPT_URL, 'http://yago.meertens.knaw.nl/SchemaParser/clear');

	my $retcode_cache = $curl_cache->perform;
	if ($retcode_cache == 0) 
	{
		#print("Cache cleared.\n");
		;
	}
	else 
	{
		# Error code, type of error, error message
		print("An error happened: $retcode_cache ".$curl->strerror($retcode_cache)." ".$curl->errbuf."\n");
	}

	# call schema service
	$curl->setopt(CURLOPT_HEADER,0);
	$curl->setopt(CURLOPT_HTTPHEADER,\@authHeader);
	$curl->setopt(CURLOPT_URL, $url);

	# A filehandle, reference to a scalar or reference to a typeglob can be used here.
	my $response_body = '';
	open(my $fileb, ">", \$response_body);
	$curl->setopt(CURLOPT_WRITEDATA,$fileb);

	# Starts the actual request
	my $retcode = $curl->perform;

	# Looking at the results...
	if ($retcode == 0) 
	{
		#print("Transfer went ok\n");
		my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);

		# judge result and next action based on $response_code
		my @lines = split(/\n/, $response_body);
	
		# write the mapping to a lookup file, note: lots of heuristics
		check_not_dir(undef, "mapping"); 
		open(MAP, "> mapping/$lookupFile.csv") or die("Could not open, $!");
		# parse the lines and store in a mapping table
		for(my $i = 0 ; $i < @lines ; $i++) 
		{
			# write to lookup file
			print MAP "$lines[$i]\n";
			if($lines[$i] =~ /(.*);(.*);(.*);\[(.*)\]/) {
				my $xpath = $1;
				my $isocatno = $2;
				my $type = $3;
				my $isocatlabel = $4;

				if($xpath =~ /\@/) 
				{
					;
				}
				elsif($isocatlabel =~ /Not response received/) 
				{
					$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
					$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
					$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
					$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
					$isocatno =~ s/DC\-471\.//g;
					$lookupTable{$xpath}{$isocatno}{$xmlSchema}++;
					$lookupTableGlob{$xpath}{$isocatno}{$xmlSchema}++;
				}
				#------------- Uncomment this elsif block if any element with content but no DC should also be indexed! ------
				elsif($isocatlabel eq "") 
				{
					my $label = $xpath;
					if($label !~ /^\/\/Md/) 
					{
						$label = lc($label);
					}
					if($isocatno eq "") 
					{
						if($label =~ m/.*\/(.+)\/(.+)$/g) 
						{
							$label =~ s/.*\/(.+)\/(.+)$/$1.$2/g;
						}
						else 
						{
							$label =~ s/.+\/(.+)$/$1/g;
						}
						$isocatno = $label;
					}
					else 
					{
						if($label =~ m/.*\/(.+)\/(.+)$/g) 
						{
							$label =~ s/.*\/(.+)\/(.+)$/$1\.$2/g;
						}
						else 
						{
							$label =~ s/.+\/(.+)$/$1/g;
						}
						$isocatno = $label;
					}
					$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
					$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
					$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
					$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
					$isocatno =~ s/DC\-471\.//g;
					$lookupTable{$xpath}{$isocatno}{$xmlSchema}++;
					$lookupTableGlob{$xpath}{$isocatno}{$xmlSchema}++;
				}
				else 
				{
					$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
					$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
					$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
					$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
					$isocatno =~ s/^DC\-471\.//g;
					$lookupTable{$xpath}{$isocatno}{$xmlSchema}++;
					$lookupTableGlob{$xpath}{$isocatno}{$xmlSchema}++;
				}
			}
		}
		close(MAP);

		open(OUT, "> $outFile") or die("Could not open $outFile");
		print OUT '<xsl:stylesheet version="2.0"
			xmlns:saxon="http://saxon.sf.net/"
			xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
			<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="no"/>
			<xsl:strip-space elements="*"/>';

		print OUT "\n";

		print OUT '<xsl:template match="/">
				<add>
						<xsl:apply-templates />
				</add>
			</xsl:template>';

		print OUT "\n";

		# generate XSLT templates on-the-fly based on the look-up table with a loop
		print OUT '<xsl:template match="//CMD">
									<doc>

									<field name="fulltext">
									<xsl:value-of select="normalize-space(.)"/>
									</field>

									<field name="schemaLocation">
									<xsl:value-of select="@schemaLocation"/>
									</field>
								
									<field name="schemaName">
									<xsl:text>' . $schemaNames{$xmlSchema} . '</xsl:text>
									</field>									

										<xsl:apply-templates />
									</doc>
		</xsl:template>';
		print OUT "\n";

		print OUT '<xsl:template match="Components/OLAC-DcmiTerms/publisher" priority="100">
							<field name="collection">
								<xsl:value-of select="."/>
							</field>
					</xsl:template>';
		print OUT "\n";

		foreach my $xpath (sort keys %lookupTable) 
		{
			my $priority = length($xpath);

			if($xpath ne "//MdCollectionDisplayName") 
			{
				print OUT '<xsl:template match="' . $xpath . '" priority="' . $priority . '">';
				print OUT "\n";
				foreach my $isocatno (keys %{$lookupTable{$xpath}}) 
				{
					# Insert into catchall 'text' field
					if($isocatno eq "") 
					{
						;
					}
		  elsif($isocatno eq "MdCreationDate") 
		  {
			print OUT '	<field name="MdCreationDate">
				<xsl:value-of select="normalize-space(replace(., \'^.*\s*(\d{4}-\d{2}-\d{2}).*\', \'$1\'))"/>
				<xsl:text>T00:00:00Z</xsl:text>
			</field>';
			print OUT "\n";
		  }					
					# Insert regular templates
					else 
					{
						if($isocatno ne "MdCollectionDisplayName") 
						{
			  print OUT '<xsl:choose>
						<xsl:when test="count(descendant::*) != 0">
						  <field name="' . $isocatno .'"><xsl:value-of select="normalize-space(string-join(descendant::*, \' \'))"/></field>
						</xsl:when>
						<xsl:otherwise>
						  <field name="' . $isocatno .'"><xsl:value-of select="normalize-space(.)"/></field>
						</xsl:otherwise>
						</xsl:choose>';
						}
					}
				}

				print OUT "<xsl:apply-templates />\n";
			}

			if($xpath eq "//MdCollectionDisplayName") 
			{
				print OUT '<xsl:template match="Header/MdCollectionDisplayName">
									<field name="collection">
										<xsl:value-of select="."/>
									</field>
									<xsl:apply-templates />
							</xsl:template>';
				print OUT "\n";
			}

			if($xpath ne "//MdCollectionDisplayName") 
			{
				print OUT '</xsl:template>';
				print OUT "\n";
			}
		}
		#

		print OUT "\n";

		print OUT "\n";

		print OUT '<xsl:template match="text()|@*"/>';

		print OUT "\n";

		print OUT '</xsl:stylesheet>';

		print OUT "\n";

		close(OUT);
	}
	else {
		# Error code, type of error, error message
		print("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
	
		# perhaps it should die here, but I have not set it because the XML schema parser is a bit buggy and I want to continue index something
		# die("Profile could not be extracted by the XML schema parser. Check out why not!\n");
	}
}

#----------------------------------------------
# subroutine to generate a single global XSLT
# In  : none
# Out : XSLT
#----------------------------------------------
sub extract_xsl_all  
{
  my ( $self ) = @_;
  
  check_not_dir(undef, "indexSchemas");  
  open(OUT, "> indexSchemas/all.xsl") or die("Could not open indexSchemas/all.xsl, $!");
  print OUT '<xsl:stylesheet version="2.0"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="no"/>
    <xsl:strip-space elements="*"/>';

  print OUT "\n";

  print OUT '<xsl:template match="/">
      <add>
          <xsl:apply-templates />
      </add>
    </xsl:template>';

  print OUT "\n";

  print OUT '<xsl:template match="//CMD">
                <doc>

                <field name="fulltext">
                <xsl:value-of select="normalize-space(.)"/>
                </field>

                <field name="schemaLocation">
                <xsl:value-of select="@schemaLocation"/>
                </field>

                  <xsl:apply-templates />
                </doc>
  </xsl:template>';
  print OUT "\n";

  print OUT '<xsl:template match="Components/OLAC-DcmiTerms/publisher" priority="100">
            <field name="collection">
              <xsl:value-of select="."/>
            </field>
        </xsl:template>';

  print OUT "\n";

  foreach my $xpath (sort keys %lookupTableGlob) 
  {
    my $priority = length($xpath);

    if($xpath ne "//MdCollectionDisplayName") 
    {
      print OUT '<xsl:template match="' . $xpath . '" priority="' . $priority . '">';
      print OUT "\n";
      foreach my $isocatno (keys %{$lookupTableGlob{$xpath}}) 
      {
        # Insert into catchall 'text' field
        if($isocatno eq "") 
        {
          ;
        }
        # Insert regular templates
        else 
        {
          if($isocatno ne "MdCollectionDisplayName") 
          {
            print OUT '	<field name="' . $isocatno .'"><xsl:value-of select="normalize-space(.)"/></field>';
          }
        }
      }

      print OUT "<xsl:apply-templates />\n";
    }

    if($xpath eq "//MdCollectionDisplayName") 
    {
      print OUT '<xsl:template match="Header/MdCollectionDisplayName">
                <field name="collection">
                  <xsl:value-of select="."/>
                </field>
                <xsl:apply-templates />
            </xsl:template>';
      print OUT "\n";
    }

    if($xpath ne "//MdCollectionDisplayName") 
    {
      print OUT '</xsl:template>';
      print OUT "\n";
    }
  }
  #
  print OUT "\n";
  print OUT "\n";
  print OUT '<xsl:template match="text()|@*"/>';
  print OUT "\n";
  print OUT '</xsl:stylesheet>';
  print OUT "\n";
  close(OUT);
}

#-------------------------------------------------------------
# subroutine that stores the ISOcat mapping in a global hash
# In  : XML Schema reference
# Out : human-readable labels of the fields in a hash
#-------------------------------------------------------------
sub extract_labels 
{
  my ( $self, $xmlSchema ) = @_;

  my $outFile = extract_xml_schema_clean(undef, $xmlSchema);
	my $lookupFile = $outFile;

	open(MAP, "< mapping/$lookupFile.csv") or die("Could not open, $!");
	my @lines = <MAP>;

	# parse the lines and store in a mapping table
	for(my $i = 0 ; $i < @lines ; $i++) 
	{
		# xPath;indexField;Type;Labels[]
		if($lines[$i] =~ /(.*);(.*);(.*);\[(.*)\]/) 
		{
			my $xpath = $1;
			my $isocatno = $2;
			my $type = $3;
			my $isocatlabel = $4;

			if($xpath =~ /\@/) 
			{
				;
			}
			elsif($isocatlabel =~ /Not response received/) 
			{
				my $label = $xpath;
				$label =~ s/\///g;
				if($label !~ /^\/\/Md/) 
				{
					$label = lc($label);
				}

				$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
				$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
				$isocatno =~ s/DC\-471\.//g;
				$label =~ s/^source\,//;
				$lookup_table_labels{$isocatno}{$label}++;
			}
			elsif($isocatlabel eq "") 
			{
				my $label = $xpath;
				if($label !~ /^\/\/Md/) 
				{
					$label = lc($label);
				}
				if($label =~ m/.*\/(.+)\/(.+)$/g) 
				{
					# when parent and child have same name, merge
					my $label1 = $label;
					my $label2 = $label;

					$label1 =~ s/.*\/(.+)\/(.+)$/$1/g;
					$label2 =~ s/.*\/(.+)\/(.+)$/$2/g;

					if($label1 eq $label2) 
					{
						$label =~ s/.*\/(.+)\/(.+)$/$1\.$2/g;
						$isocatno = $label;
						$label =~ s/(.+)\.(.+)/$2/g;
					}
					else 
					{
						$label =~ s/.*\/(.+)\/(.+)$/$1\.$2/g;
						$isocatno = $label;
						$label =~ s/(.+)\.(.+)/$2 $1/g;
					}
				}
				else 
				{
					$label =~ s/.+\/(.+)$/$1/g;
					$isocatno = $label;
				}

				$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
				$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
				$isocatno =~ s/DC\-471\.//g;
				$label =~ s/^source\,//;
				$lookup_table_labels{$isocatno}{$label}++;
			}
			else 
			{
				$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
				$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
				$isocatno =~ s/DC\-471\.//g;

				$isocatlabel =~ s/^,//;

				if($isocatlabel !~ /^\/\/Md/) 
				{
					$isocatlabel = lc($isocatlabel);
				}

				# when parent and child have same name, merge
				my $label1 = $isocatlabel;
				my $label2 = $isocatlabel;
				$label1 =~ s/(.+)\,(.+)/$1/g;
				$label2 =~ s/(.+)\,(.+)/$2/g;

				if($label1 eq $label2) 
				{
					$isocatlabel = $label1;
				}
				elsif($isocatlabel =~ m/.*\/(.+)\/(.+)$/g) 
				{
					$isocatlabel=~ s/.*\/(.+)\/(.+)$/$2 $1/g;
				}
				else 
				{
					$isocatlabel =~ s/.+\/(.+)$/$1/g;
				}
				$isocatlabel =~ s/^source\,//;

				$lookup_table_labels{$isocatno}{$isocatlabel}++;
			}
		}
	}
	close(MAP);
}

#----------------------------------------------------------------
# subroutine to extract schema information to a global hash
# In  : XML schema reference
# Out : information to global hash
#----------------------------------------------------------------
sub extract_schema_to_hash 
{
  my ( $self, $xmlSchema ) = @_;
  
	my $lookupFile = extract_xml_schema_clean(undef, $xmlSchema);

	open(MAP, "< mapping/$lookupFile.csv") or die("Could not open, $!");
	my @lines = <MAP>;

	# parse the lines and store in a mapping table
	for(my $i = 0 ; $i < @lines ; $i++) 
	{
		if($lines[$i] =~ /(.*);(.*);(.*);\[(.*)\]/) 
		{
			my $xpath = $1;
			my $isocatno = $2;
			my $type = $3;
			my $isocatlabel = $4;

			if($xpath =~ /\@/) 
			{
				;
			}
			elsif($isocatlabel =~ /Not response received/) 
			{
				$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
				$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
				$isocatno =~ s/DC\-471\.//g;
				$lookupTableGlob{$xpath}{$isocatno}{$type}++;
			}
			#------------- Uncomment this block if any element with content but no DC should also be indexed! ------
			elsif($isocatlabel eq "") 
			{
				my $label = $xpath;
				if($label !~ /^\/\/Md/) 
				{
					$label = lc($label);
				}
				if($isocatno eq "") 
				{
					if($label =~ m/.*\/(.+)\/(.+)$/g) 
					{
						$label =~ s/.*\/(.+)\/(.+)$/$1.$2/g;
					}
					else 
					{
						$label =~ s/.+\/(.+)$/$1/g;
					}
					$isocatno = $label;
				}
				else 
				{
					if($label =~ m/.*\/(.+)\/(.+)$/g) 
					{
						$label =~ s/.*\/(.+)\/(.+)$/$1\.$2/g;
					}
					else 
					{
						$label =~ s/.+\/(.+)$/$1/g;
					}
					$isocatno = $label;
				}

				$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
				$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
				$isocatno =~ s/DC\-471\.//g;
				$lookupTableGlob{$xpath}{$isocatno}{$type}++;
			}
			else 
			{
				$isocatno =~ s/http:\/\/www.isocat.org\/datcat\///g;
				$isocatno =~ s/http:\/\/www.isocat.org\/rest\/dc\/(\d+)/DC-$1/g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/terms\///g;
				$isocatno =~ s/http:\/\/purl.org\/dc\/elements\/1\.1\///g;
				$isocatno =~ s/DC\-471\.//g;
				$lookupTableGlob{$xpath}{$isocatno}{$type}++;
			}
		}
	}
	close(MAP);
}

#----------------------------------------------------------------
# subroutine to create a new Solr schema.xml
# In  : file name
# Out : new schema.xml to STDOUT
#----------------------------------------------------------------
sub create_new_solr_schema 
{
  my ( $self, $file ) = @_;
    
  # read example schema.xml
  open(SCHEMA, "<", $file) or die("Could not open $!");

  my $commentFlag = 0;
  # print out the modified schema.xml
  while(<SCHEMA>) {
    # If comment, then omit
    if($_ =~ /<!--.*-->/) 
    {
      $commentFlag = 0;
    }
    elsif($_ =~ /<!--/) 
    {
      $commentFlag = 1;
    }
    elsif($_ =~ /-->/) 
    {
      $commentFlag = 0;
    }
    else
    {
      if($commentFlag == 1) 
      {
        ;
      }
      else 
      {
        # If match <fields>, then
        if($_ =~ /<fields>/) 
        {
          #-------------------------------------------------------------
          # Print the <field> declarations
          #-------------------------------------------------------------
          print("<fields>\n");

          my %fields = ();
          foreach my $xpath (keys %lookupTableGlob) 
          {
            foreach my $isocatno (keys %{$lookupTableGlob{$xpath}}) 
            {
              my $dataString = "textgen";
  # 						foreach my $type (keys %{$lookupTable{$xpath}{$isocatno}}) {
  #  							print("$xpath\t$isocatno\n");
  # 							if($type eq "string\@http://www.w3.org/2001/XMLSchema") {
  # 								$type = "textgen";
  # 							}
  # 							elsif($type eq "gYear\@http://www.w3.org/2001/XMLSchema") {
  # 								$type = "tint";
  # 							}
  # 							elsif($type eq "date\@http://www.w3.org/2001/XMLSchema") {
  # 								$type = "textgen";
  # 							}
  # 							elsif($type eq "anyURI\@http://www.w3.org/2001/XMLSchema") {
  # 								$type = "textgen";
  # 							}
  # 							else {
  # 								$type = "textgen";
  # 							}
  # 							$dataString = $type;
  # 						}

              #-------------------------------------------------------------
              # <field> declaration for 'id'
              #-------------------------------------------------------------
              if($xpath eq "//MdSelfLink") 
              {
                print("<field name=\"MdSelfLink\" type=\"string\" indexed=\"true\" stored=\"true\" required=\"true\"/>\n");
              }

              elsif($xpath eq "//MdCreationDate") 
              {
                print("<field name=\"MdCreationDate\" type=\"string\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"false\"/>\n");
              }
            
              #-------------------------------------------------------------
              # <field> declaration with an ISOcat number
              #-------------------------------------------------------------
              else 
              {
                if($isocatno ne "") 
                {
                  #-------------------------------------------------------------
                  # these fields need to be sortable, so multiValued = false!
                  #-------------------------------------------------------------
                
                  # publication dates
                  if($isocatno eq "DC-2538") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"$dataString\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"false\"/>\n"}++;
                  }
                  # given name
                  elsif($isocatno eq "DC-4194") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"$dataString\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"false\"/>\n"}++;
                  }
                  # last name
                  elsif($isocatno eq "DC-4195") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"$dataString\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"false\"/>\n"}++;
                  }	
                  # genre
                  elsif($isocatno eq "DC-2470") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"string\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"true\"/>\n"}++;
                  }
                  # subgenre									
                  elsif($isocatno eq "DC-3899") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"string\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"true\"/>\n"}++;
                  }
                  # auteur_id + titel_id
                  elsif($isocatno eq "auteur_id") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"string\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"true\"/>\n"}++;
                  }							
                  elsif($isocatno eq "titel_id") 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"string\" indexed=\"true\" stored=\"true\" termVectors=\"false\" multiValued=\"true\"/>\n"}++;
                  }																	
                  # drop fulltext and text because these will be duplicate!
                  elsif($isocatno eq "fulltext") 
                  {
                    ;
                  }
                  elsif($isocatno eq "text") 
                  {
                    ;
                  }																
                  else 
                  {
                    $fields{"<field name=\"$isocatno\" type=\"$dataString\" indexed=\"true\" stored=\"true\" termVectors=\"true\" multiValued=\"true\"/>\n"}++;
                  }
                }
              }
            }
          }
          #-------------------------------------------------------------
          # Print all field declarations
          #-------------------------------------------------------------
          foreach my $fieldDeclaration (keys %fields) 
          {
            print("$fieldDeclaration\n");
          }

          #-------------------------------------------------------------
          # Print the catchall field 'text'
          #-------------------------------------------------------------
          #print("<field name=\"DC-X\" type=\"text_general\" indexed=\"true\" stored=\"true\" multiValued=\"true\"/>\n");
          print("<field name=\"fulltext\" type=\"textgen\" indexed=\"true\" stored=\"true\" termVectors=\"true\" multiValued=\"true\"/>\n");
          print("<field name=\"text\" type=\"textgen\" indexed=\"true\" stored=\"true\" multiValued=\"true\"/>\n");
          print("<field name=\"collection\" type=\"string\" indexed=\"true\" stored=\"true\" multiValued=\"true\"/>\n");
          print("<field name=\"schemaLocation\" type=\"string\" indexed=\"true\" stored=\"true\" multiValued=\"false\"/>\n");
          print("<field name=\"schemaName\" type=\"string\" indexed=\"true\" stored=\"true\" multiValued=\"false\"/>\n");
          print("<field name=\"_version_\" type=\"long\" indexed=\"true\" stored=\"true\"/>");
          #print("<field name=\"MdSelfLink\" type=\"string\" indexed=\"true\" stored=\"true\" multiValued=\"true\"/>\n");
        }

        # If match <field>, then omit
        elsif($_ =~ /<field\s+/) 
        {
          ;
        }

        # If match <copyField>, then omit
        elsif($_ =~ /<copyField\s+/) 
        {
          ;
        }

        #-------------------------------------------------------------
        # Insert copyFields
        #-------------------------------------------------------------
        elsif($_ =~ /<solrQueryParser\s+/) 
        {
          print("$_");
          #print("<copyField source=\"DC*\" dest=\"text\"/>\n");
        }

        # Append <copyField> at the end of the file
        elsif($_ =~ /<\/schema>/) 
        {
          ;
          print "</schema>";
        }

        # Else, just print the line
        else 
        {
          print "$_";
        }
      }
    }
  }

  close(SCHEMA);
}

#----------------------------------------------------------------
# subroutine to print index fields for Solr caching
# In  : file name
# Out : list of fields that should be cached first time in Solr
#----------------------------------------------------------------
sub print_solr_cache_labels 
{
  my ( $self, $file ) = @_;
  
  open(FILE, ">", $file) or die("Could not write to file, $!\n");
  print FILE '<str name="facet">true</str>' . "\n";
  print FILE '<str name="facet.field">collection</str>' . "\n";
  print FILE '<str name="facet.field">schemaLocation</str>' . "\n";
  print FILE '<str name="facet.field">schemaName</str>' . "\n";
  foreach my $isocat (sort keys %lookup_table_labels) 
  {
    print FILE '<str name="facet.field">' . $isocat . '</str>' . "\n";
  }
  close(FILE);
}

#----------------------------------------------------------------------
# subroutine to print index fields and labels for use in Ajax Solr UI
# In  : none
# Out : STDOUT 2 JS arrays with index fields and labels
#----------------------------------------------------------------
sub print_ajax_solr_labels
{
  my ( $self ) = @_;
  
  my $isocatArray = "var fieldsArray = [ 'collection','schemaLocation','schemaName',";
  my $labelArray = "var fieldsLabels = [ 'collection','schemaLocation','schemaName',";

  my $fieldsAutoArray = "var fieldsAutoArray = [ ";
  my $fieldsAutoLabels = "var fieldsAutoLabels = [ ";

  foreach my $isocat (sort keys %lookup_table_labels) 
  {
    foreach my $label (keys %{$lookup_table_labels{$isocat}}) 
    {
      $isocatArray .= "'" . $isocat . "',";
      $fieldsAutoArray .= "'" . $isocat . "',";

      $label =~ s/,/→/g;
      $label =~ s/'s//g;
      #$label = lc($label);

      $labelArray .= "'" . $label . "',";
      $fieldsAutoLabels .= "'" . $label . "',";
    }
  }

  $isocatArray .= "'text','fulltext' ];";
  $labelArray .= "'text','fulltext' ];";

  $fieldsAutoArray .= " ];";
  $fieldsAutoLabels .= " ];";

  $fieldsAutoArray =~ s/\,( \]\;$)/$1/g;
  $fieldsAutoLabels =~ s/\,( \]\;$)/$1/g;

  print $isocatArray . "\n";
  print $labelArray . "\n";

  print $fieldsAutoArray. "\n";
  print $fieldsAutoLabels . "\n";
}

#-----------------------------------------------------------------
# subroutine to clean XML schema in a clean name for file system
# In  : scalar with reference to XML schema
# Out : clean name
#-----------------------------------------------------------------
sub extract_xml_schema_clean 
{
  my ( $self, $schema ) = @_;
  
  my $outFile = $schema;

	$outFile =~ s/.*\/(.+)\/xsd$/$1/;
	$outFile =~ s/.*\/(.+\/.+)$/$1/;

	# need to ESCAPE certain tokens to make it work smooth, yeah!
	$outFile =~ s/\//./g;
	$outFile =~ s/\:/./g;
	$outFile =~ s/\?/-/g;
	$outFile =~ s/\=/-/g;
	$outFile =~ s/\./_/g;

	chomp($outFile);
	
	return $outFile;
}

#-----------------------------------------------------------------
# subroutine to read list of files from directory
# In  : directory name
# Out : array with files
#-----------------------------------------------------------------
sub read_files_from_dir
{
  my ( $self, $dir ) = @_;
  
  opendir(D, "$dir") || die "Can't open dir $dir: $!\n";
  my @list = readdir(D);
  closedir(D);  
  
  return @list;
}

#-------------------------------------------------------
# subroutine to print value of variable for debugging
# In  : scalar variable or array
# Out : raw value of variable
#-------------------------------------------------------
sub debug_var_scalar 
{
  my ( $self, $var ) = @_;

  dump($var);
}
sub debug_var_array
{
  my ( $self, @var ) = @_;

  dump(@var);
}

# The last line in any module should be
1;