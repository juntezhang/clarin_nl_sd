#!/bin/bash
#@--------------------------------------------------------------------------------
#@ By Junte Zhang <juntezhang@gmail.com> in 2013
#@ Distributed under the GNU General Public Licence
#@
#@ This shell script automates the CMDI MI indexing procedure 
#@---------------------------------------------------------------------------------

# store start time
START=$(date +%s)

#--------------------------------------------------------------
# declare variables
#--------------------------------------------------------------
# Paths
script_path=/Development/clarin/scripts
web_js_path=/Library/WebServer/Documents/solr/cmdi-dev-eu/js
index_management_path=http://localhost/solr/cmdi-dev-eu/editRecord
solr_config_path=/Development/apache-solr-4.4.0/example/cmdi-eu/conf

# XML
schema=$solr_config_path/schema.xml

# JS
labels4user=$web_js_path/cmdi.labels.js

# PHP, sorry cannot remember why I wrote this script in PHP...
profilenames=$script_path/cmdi-profile-names.php

# Perl
createlist=$script_path/cmdi-list-per-schema.pl
cmdi2xslt=$script_path/cmdi-xsl-per-schema.pl
cmdi2schema=$script_path/cmdi-data-per-schema.pl
schema2solr=$script_path/cmdi-schemas2solr.pl
labels2solr=$script_path/cmdi-labels4solr.pl

# XSLT
saxon=/Software/saxonb9-1-0-8j/saxon9.jar

case $1 in
  #--------------------------------------------------------------
  # --preprocess: only process the data and extract its schemas
  #--------------------------------------------------------------
   "--preprocess"|"-p") 
    echo "";
    # create an overview first
    echo "Compiling the CMDI list and extract XML schemas...(1/9)"
    time perl $createlist
    
    # retrieve the MdProfile names
    echo "Retrieving the MdProfile names...(2/9)"
    time php $profilenames
    echo "";
     ;;
  #--------------------------------------------------------------
  # --compile: only compile the data and its schemas
  #--------------------------------------------------------------     
   "--compile"|"-c") 
    echo "";   
    # create XSLT stylesheet to map each CMDI to indexing format
    echo "Compiling the XSLT stylesheets per profile...(3/9)"
    time perl $cmdi2xslt
    
    echo "Compiling the index data files...(4/9)"
    time perl $cmdi2schema
    echo "";
     ;;
  #--------------------------------------------------------------
  # --index: only index the data 
  #--------------------------------------------------------------         
   "--index"|"-i") 
    echo "";
    echo "Starting the indexing..."

    # create a schema.xml
    echo "Compiling the Lucene schema.xml file...(5/9)"
    time perl $schema2solr > $schema
  
    # extract the labels
    echo "Extracting the labels...(6/9)"
    time perl $labels2solr > $labels4user
  
    # restart the Solr server
    echo "Reload the cmdi Solr core...7/9)"
    time curl $index_management_path/index_management.php?status=reload&server=local
  
    # delete the index
    echo "Emptying the index...(8/9)"
    time curl $index_management_path/index_management.php?status=delete&server=local
  
    # update the index
    echo "Updating and optimizing the index...(9/9)"
    time curl $index_management_path/index_management.php?status=update&server=local
    time curl $index_management_path/index_management.php?status=optimize&server=local
  
    echo "SUCCESS! The indexing procedure has been finished!"   
    echo ""; 
     ;;
  #--------------------------------------------------------------
  # --all: do it all at once 
  #--------------------------------------------------------------     
   "--all"|"-a") 
    echo "";
    echo "Starting the indexing procedure..."
   
    # create an overview first
    echo "Compiling the CMDI list and extract XML schemas...(1/9)"
    time perl $createlist
    
    # retrieve the MdProfile names
    echo "Retrieving the MdProfile names...(2/9)"
    time php $profilenames   
   
    # create XSLT stylesheet to map each CMDI to indexing format
    echo "Compiling the XSLT stylesheets per profile...(3/9)"
    time perl $cmdi2xslt
    
    echo "Compiling the index data files...(4/9)"
    time perl $cmdi2schema
       
    #break off NOW if this step fails!!!
    if [ "$?" -eq "0" ]; then
      # create a schema.xml
      echo "Compiling the Lucene schema.xml file...(5/9)"
      time perl $schema2solr > $schema
    
      # extract the labels
      echo "Extracting the labels...(6/9)"
      time perl $labels2solr > $labels4user
    
      # restart the Solr server
      echo "Reload the cmdi Solr core...7/9)"
      time curl $index_management_path/index_management.php?status=reload&server=local
    
      # delete the index
      echo "Emptying the index...(8/9)"
      time curl $index_management_path/index_management.php?status=delete&server=local
    
      # update the index
      echo "Updating and optimizing the index...(9/9)"
      time curl $index_management_path/index_management.php?status=update&server=local
      time curl $index_management_path/index_management.php?status=optimize&server=local
    
      echo "SUCCESS! The indexing procedure has been finished!"
      echo "";
    else
      echo "Error: index data could not be compiled. Indexing procedure stopped."
      echo "";
    fi
     ;;
  #-----------------------------------------------------------------------
  # --help: print out instructions on how to use this script 
  #-----------------------------------------------------------------------          
   "--help"|"-h")
    echo "";
    echo "Usage: $0 [arguments]";
    printf "\t%-20s\t%-20s\n" "--preprocess or -p" "only process the data and extract its schemas";
    printf "\t%-20s\t%-20s\n" "--compile or -c" "only compile the data and its schemas";
    printf "\t%-20s\t%-20s\n" "--index or -i" "only index the data";
    printf "\t%-20s\t%-20s\n" "--all or -a" "do it all at once";
    echo "";   
     ;;     
  #--------------------------------------------------------------
  # catch all: print out instructions
  #--------------------------------------------------------------          
   *) 
    echo "";
    echo "Please provide a parameter.";
    echo "See $0 --help for more information.";
    echo "";
   ;;
esac

# print time needed to execute the script
END=$(date +%s)
DIFF=$(( $END - $START ))
echo ""
echo "It took $DIFF seconds to execute this script."
echo "";

exit 1
