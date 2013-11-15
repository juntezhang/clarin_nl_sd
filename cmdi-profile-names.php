<?php
#@--------------------------------------------------------------------------
#@ Copyright 2013 by Junte Zhang <juntezhang@gmail.com>
#@ Distributed under the GNU General Public Licence
#@
#@ This script extracts the CMDI profile names for display purposes
#@--------------------------------------------------------------------------
$data = file_get_contents("./schemas.tmp");
$schemas_arr = explode("\n", $data);

# delete last empty element
array_pop($schemas_arr);

# output file
$out = 'schemasNames.tmp';

# start a new file
file_put_contents($out, "");

foreach($schemas_arr as $val) 
{
  $file = preg_replace("/.*\/(.+)\/xsd$/", "$1", $val);
  if(preg_match("/clarin/", $file)) 
  {
    $xml_url = 'http://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/profiles/' . $file . '/xml';

    $ch = curl_init();

    $header = array("Content-type:text/xml; charset=utf-8");
    curl_setopt($ch, CURLOPT_URL, $xml_url);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.8.1) Gecko/20061010 Firefox/2.0"); # had Lysander dit maar gedaan

    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT ,0);
    curl_setopt($ch, CURLOPT_TIMEOUT, 0); # timeout in seconds

    curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    curl_setopt($ch, CURLINFO_HEADER_OUT, 0);

    $response = curl_exec($ch);
    $info = curl_getinfo($ch);
    if ($response === false || $info['http_code'] != 200) 
    {
      $response = "No cURL data returned for $xml_url [". $info['http_code']. "]\n";

      echo $response;
      die("No cUrl data returned. Exiting script...");
    }
    else 
    {
      $dom = new DOMDocument();
      $dom->loadXML($response);

      $xpath = new DOMXPath($dom);

      $profile_name = $xpath->query("//Header/Name");

      if($profile_name->length != 1) 
      {
        ;
      } 
      else 
      {
        $line =  $val . "\t" . $profile_name->item(0)->nodeValue . "\n";
        file_put_contents($out, $line, FILE_APPEND);
      }
    }
  }
}
?>