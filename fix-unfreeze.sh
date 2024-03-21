#!/bin/bash

# The purpose of this script is to fix sites that failed unfreezing.
# The script takes an input file containg a list of sites, one per line.
# The script restores backups twice to the dev, test, and live environment of each site.
# This could process is destructive, so be careful.


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
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0;0m'

check_terminus_output () {
  # This function is here to check whether the first restore attempt for any given site returns an error.
  # This is to catch sites that do not have a codeserver provisioned.
  SITE_NAME=$1
  SITE_ENV=$2
  TERMINUS_OUTPUT=$3
  
  if grep -q "error" $TERMINUS_OUTPUT; then
    echo $SITE_NAME.$SITE_ENV >> fix-unfreeze-error-verbose.log
    echo $TERMINUS_OUTPUT >> fix-unfreeze-error-verbose.log
    return
  fi

  # Return false in case error was not found in output file.
  false
}

restore () {
  # This function runs the restore process twice in each environment for the specified site.
  SITE=$1

  # For the first restore attempt on the dev environment, we are sending the output to a file so that we can check for errors in case a codeserver is not provisioned.
  # If this happens, the script will skipt the rest of the restore attempts for the site as this will require manual intervention.
  # Check the fix-unfreeze-error.log file for a list of sites that are returning errors.
  echo -e "${GREEN}Restoring $SITE.dev${RESET}"
  terminus --yes backup:restore -- $SITE.dev >> /tmp/terminus_out 2>&1
  if check_terminus_output $SITE_NAME dev /tmp/terminus_out; then
    echo $SITE >> fix-unfreeze-error.log
    echo -e "${RED}Restore failed on $SITE, likely due to missing codeserver. Logged in fix-unfreeze-error.log${RESET}"
  else 
    # If the first restore attempt is successful, proceed with the rest.
    echo -e "${GREEN}Restoring $SITE.test${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.test 
    echo -e "${GREEN}Restoring $SITE.live${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.live
    echo -e "${GREEN}Starting second restore on $SITE.dev${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.dev
    echo -e "${GREEN}Starting second restore on $SITE.test${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.test
    echo -e "${GREEN}Starting second restore on $SITE.live${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.live 

    # Check the platform domains for each environment to look for a 200 response. If the environment is still returning an error code, it may require manual intervention.
    # Check the fix-unfreeze-badresponse.log for a list of sites.
    sleep 60
    for env in {dev,test,live} ; do
      response=`curl -I "https://$env-$SITE.pantheonsite.io/" 2> /dev/null | grep HTTP | cut -d" " -f2`
      if [ $response != "200" ] ; then
        echo "https://$env-$SITE.pantheonsite.io" >> fix-unfreeze-badresponse.log
        echo -e "${RED}Bad response from https://$env-$SITE.pantheonsite.io ($response). Recorded in fix-unfreeze-badresponse.log${RESET}"
      else
        echo -e "${GREEN}200 response from https://$env-$SITE.pantheonsite.io${RESET}"
      fi
    done 
  fi
}

# Loop through the input file and run the restore function in the background for each site so that we can restore multiple sites at once.
for site in ${SITES[@]}; do
  restore $site &
done

