#!/bin/bash

# Pass an IP to this script and it will output the subject and issuer of the certificates installed for the domain on whatever the public name is pointed to and each of the platform endpoints.

# Checks for required input or prompts for it.
if [ "$1" ]; then
  site=$1
else
  echo "Domain name: "
  read site
fi

    echo $site:
    live_subject=`curl -vik "https://$site" 2>&1 | grep -E 'subject:' | cut -d: -f2 `
    live_issuer=`curl -vik "https://$site" 2>&1 | grep -E 'issuer:' | cut -d: -f2`
    echo Live cert subject: $live_subject
    echo Live cert issuer: $live_issuer

    # Loop through platform offsets
    for offset in {1,2,3,4,253} ; do 
      plat_subject=`curl -vik --resolve $site:443:23.185.0.$offset "https://$site" 2>&1 | grep -E 'subject:' |  cut -d: -f2 | grep -v pantheonsite.io`
      plat_issuer=`curl -vik --resolve $site:443:23.185.0.$offset "https://$site" 2>&1 | grep -E 'issuer:' | cut -d: -f2`

      # Check for instances not serving a pantheonsite.io certificate and output the details
      if [[ ! $plat_subject == "" ]] ; then
        echo Platform IP: 23.185.0.$offset
        echo Platform cert subject: $plat_subject 
        echo Platform cert issuer: $plat_issuer
      fi

    done
  echo

