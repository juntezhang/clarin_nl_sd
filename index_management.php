<?php
#@--------------------------------------------------------------------------------
#@ Copyright 2013 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ This script indexes data to Solr, make sure to put it in a Webserver directory
#@--------------------------------------------------------------------------------

ini_set("memory_limit","2G");

#--------------------------------------------------------------
# global variables 
#--------------------------------------------------------------
$status = '';
$dir = '';
$post_string = '';
$file = '';
$url = '';
$url2 = '';

#--------------------------------------------------------------
# URL parameters
#--------------------------------------------------------------	

# status: update, reload, delete
if(!isset($_GET["status"])) 
{
  $status = "update";
}
else 
{
  $status = $_GET["status"];
}

#--------------------------------------------------------------
# setting the Solr server, directory and filename of data 
# server:  local, cmdi-eu, cmdi-mi
#--------------------------------------------------------------
if(!isset($_GET["server"])) 
{
  $url = "http://localhost:8983/solr/cmdi-eu/update";
  $url2 = "http://localhost:8983/solr/admin/cores?action=RELOAD&core=cmdi-eu";
}
else if($_GET["server"] eq "cmdi-eu")
{
  $url = "http://openskos.meertens.knaw.nl/solr/cmdi-eu/update";
  $url2 = "http://openskos.meertens.knaw.nl/solr/admin/cores?action=RELOAD&core=cmdi-eu";	
}
else if($_GET["server"] eq "cmdi-mi")
{
  $url = "http://openskos.meertens.knaw.nl/solr/cmdi-mi/update";
  $url2 = "http://openskos.meertens.knaw.nl/solr/admin/cores?action=RELOAD&core=cmdi-mi";	
}	
else 
{
  $url = "http://localhost:8983/solr/cmdi-eu/update";
  $url2 = "http://localhost:8983/solr/admin/cores?action=RELOAD&core=cmdi-eu";
}

#-------------------------------------------------------------------------
# data: make sure the paths are correct, default the dir is of all files
#-------------------------------------------------------------------------
if(!isset($_GET["data"])) 
{
  # make these 2 paths are correct!!!
  $dir = "/Development/clarin/scripts/indexData";
  $file = "/Library/WebServer/Documents/solr/cmdi-dev-eu/editRecord/empty.xml";
}
else 
{
  $dir = $_GET["data"];
  $file = $_GET["data"];
}

#--------------------------------------------------------------
# do something with Solr given the status value 
#--------------------------------------------------------------	
switch($status)
{
  case 'update':
    $url =  $url . "?commit=true";
  
    $files = glob("$dir/*.xml");
    array_multisort(
            array_map( 'filesize', $files ),
            SORT_NUMERIC,
            SORT_ASC,
            $files
        );
    array_push($files, $files[0]);
    array_shift($files);
  
    foreach ($files as $file) 
    {
      print $file . "\n";
      $post_string = file_get_contents($file);
      $header = array("Content-type:text/xml; charset=utf-8");
  
      $ch = curl_init();
  
      curl_setopt($ch, CURLOPT_URL, $url);
      curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
      curl_setopt($ch, CURLOPT_TIMEOUT, 0);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
      curl_setopt($ch, CURLOPT_POST, 1);
      curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
      curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
      curl_setopt($ch, CURLINFO_HEADER_OUT, 1);
  
      $dat = curl_exec($ch);
      print $dat;
  
      if (curl_errno($ch)) 
      {
         print "curl_error:" . curl_error($ch);
      }
      else 
      {
         curl_close($ch);
      }
    }
  break;
  
  case 'reload':
    $url =  $url2;
    $post_string .= file_get_contents($file);
  
    $header = array("Content-type:text/xml; charset=utf-8");
  
    $ch = curl_init();
  
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
    curl_setopt($ch, CURLOPT_TIMEOUT, 0);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
    curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    curl_setopt($ch, CURLINFO_HEADER_OUT, 1);
  
    $dat = curl_exec($ch);
    print $dat;
  
    if (curl_errno($ch)) 
    {
       print "curl_error:" . curl_error($ch);
    }
    else 
    {
       curl_close($ch);
    }
  break;
  
  case 'delete':
    $url = $url . "?stream.body=%3Cdelete%3E%3Cquery%3E*:*%3C/query%3E%3C/delete%3E&commit=true";
  
    $post_string .= file_get_contents($file);
  
    $header = array("Content-type:text/xml; charset=utf-8");
  
    $ch = curl_init();
  
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
    curl_setopt($ch, CURLOPT_TIMEOUT, 0);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
    curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    curl_setopt($ch, CURLINFO_HEADER_OUT, 1);
  
    $dat = curl_exec($ch);
    print $dat;
  
    if (curl_errno($ch)) 
    {
       print "curl_error:" . curl_error($ch);
    }
    else 
    {
       curl_close($ch);
    }
  break;
  
  case 'optimize':
    $url = $url . "?optimize=true";
  
    $post_string .= file_get_contents($file);
  
    $header = array("Content-type:text/xml; charset=utf-8");
  
    $ch = curl_init();
  
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
    curl_setopt($ch, CURLOPT_TIMEOUT, 0);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
    curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    curl_setopt($ch, CURLINFO_HEADER_OUT, 1);
  
    $dat = curl_exec($ch);
    print $dat;
  
    if (curl_errno($ch)) 
    {
       print "curl_error:" . curl_error($ch);
    }
    else 
    {
       curl_close($ch);
    }
  break;
  
  default:
    $url =  $url . "?commit=true";
  
    $files = glob("$dir/*.xml");
    array_multisort(
            array_map( 'filesize', $files ),
            SORT_NUMERIC,
            SORT_ASC,
            $files
        );
    array_push($files, $files[0]);
    array_shift($files);
  
    foreach ($files as $file) 
    {
      $post_string = file_get_contents($file);
      $header = array("Content-type:text/xml; charset=utf-8");
  
      $ch = curl_init();
  
      curl_setopt($ch, CURLOPT_URL, $url);
      curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
      curl_setopt($ch, CURLOPT_TIMEOUT, 0);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
      curl_setopt($ch, CURLOPT_POST, 1);
      curl_setopt($ch, CURLOPT_POSTFIELDS, $post_string);
      curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
      curl_setopt($ch, CURLINFO_HEADER_OUT, 1);
  
      $dat = curl_exec($ch);
  
      if (curl_errno($ch)) 
      {
         print "curl_error:" . curl_error($ch);
      }
      else 
      {
         curl_close($ch);
      }
    }
}

?>