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
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0;0m'
LOGFILE=unfreeze-fix.log

check_terminus_output () {
  # This function is here to check whether the first restore attempt for any given site returns an error.
  # This is to catch sites that do not have a codeserver provisioned.
  SITE_NAME=$1
  SITE_ENV=$2
  TERMINUS_OUTPUT=$3
  if grep -q "error" $TERMINUS_OUTPUT; then
    rm $TERMINUS_OUTPUT
    return
  fi

  # Return false in case error was not found in output file.
  rm $TERMINUS_OUTPUT
  false
}

restore () {
  # This function runs the restore process twice in each environment for the specified site.
  SITE=$1

  # For the first restore attempt on the dev environment, we are sending the output to a file so that we can check for errors in case a codeserver is not provisioned.
  # If this happens, the script will skipt the rest of the restore attempts for the site as this will require manual intervention.
  # Check the $LOGFILE file for a list of sites that are returning errors.
  echo -e "${BLUE}[$SITE.dev] Restoring dev environment${RESET}"
  termout=/tmp/terminus_out_$SITE
  terminus --yes backup:restore -- $SITE.dev >> $termout 2>&1
  if check_terminus_output $SITE dev $termout ; then
    echo "[RESTORE_FAILED] $SITE" >> $LOGFILE
    echo -e "${RED}[$SITE] Restore failed, likely due to missing codeserver. Logged in $LOGFILE${RESET}"
  else 
    # If the first restore attempt is successful, proceed with the rest.
    echo -e "${BLUE}[$SITE.test] Restoring${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.test 
    echo -e "${BLUE}[$SITE.live] Restoring${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.live
    echo -e "${BLUE}[$SITE.dev] Starting second restore${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.dev
    echo -e "${BLUE}[$SITE.test] Starting second restore${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.test
    echo -e "${BLUE}[$SITE.live] Starting second restore${RESET}"
    terminus --yes --quiet backup:restore -- $SITE.live 

    terminus --quiet env:clear-cache $SITE.dev
    terminus --quiet env:clear-cache $SITE.test
    terminus --quiet env:clear-cache $SITE.live

    # Check the platform domains for each environment to look for a 200 response. If the environment is still returning an error code, it may require manual intervention.
    # Check the $LOGFILE for a list of sites.
    sleep 60
    for env in {dev,test,live} ; do
      response=`curl -I "https://$env-$SITE.pantheonsite.io/" 2> /dev/null | grep HTTP | cut -d" " -f2`
      if [ $response != "200" ] ; then
        echo "[BAD_RESPONSE_$response] https://$env-$SITE.pantheonsite.io${RESET}" >> $LOGFILE
        echo -e "${RED}[$SITE] Bad response from https://$env-$SITE.pantheonsite.io ($response). Recorded in $LOGFILE ${RESET}"
      else
        echo "[SUCCESS] $SITE.$env" >> $LOGFILE
        echo -e "${GREEN}[$SITE] 200 response from https://$env-$SITE.pantheonsite.io${RESET}"
      fi
    done 
  fi
}

# Loop through the input file and run the restore function in the background for each site so that we can restore multiple sites at once.
increment=0
for site in ${SITES[@]}; do

  # Make sure fewer than 8 process are running to avoid overwhelming ygg.
  while [[ 8 -lt "`ps | grep unfreeze-fix.sh | wc -l`" ]]; do
    echo "Too many restores running. Waiting for processes to finish to avoid overwhelming ygg."
    sleep 60
  done

  # Increment a counter and run the 5th restore in the foreground and reset counter to avoid overwhelming ygg.
  if [[ 4 -gt $increment ]] ; then
    ((increment++))
    restore $site &
  else
    increment=0
    restore $site
  fi

done

