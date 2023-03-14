#!/bin/bash

# This script takes a list of domains and outputs the subject and issuer of the certificate on the site.
# Then it checks each of the Pantheon  offsets for a certificate associated with that domain name and outputs the subject and issuer if it finds any.
# This will help determine whether a domain is using a custom certificate or Let's Encrypt on the platform behind another public-facing platform which is serving a different certificate to users.

# Checks for required input or prompts for it.
if [ "$1" ]; then
  INPUT_FILE=$1
else
  echo "Input file: "
  read INPUT_FILE
fi

# Check to see if the input file exists.
if [[ ! -f $INPUT_FILE ]]; then
  echo "Input file not found."
  exit 1
fi

SITES=`cat $INPUT_FILE`

# Loop through the input file.
for site in ${SITES[@]}; do
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
done

