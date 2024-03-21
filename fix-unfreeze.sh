#!/bin/bash


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
  SITE=$1
  echo -e "${GREEN}Restoring $SITE.dev${RESET}"
  terminus --yes backup:restore -- $SITE.dev >> /tmp/terminus_out 2>&1
  if check_terminus_output $SITE_NAME dev /tmp/terminus_out; then
    echo $SITE >> fix-unfreeze-error.log
    echo -e "${RED}Restore failed on $SITE, likely due to missing codeserver. Logged in fix-unfreeze-error.log${RESET}"
  else 
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
    sleep 60

    for env in {dev,test,live} ; do
      response=`curl -I "https://$env-$SITE.pantheonsite.io/" 2> /dev/null | grep HTTP | cut -d" " -f2`
      if [ $response != "200" ] ; then
        echo "https://$env-$SITE.pantheonsite.io" >> fix-unfreeze-badresponse.log
        echo -e "${RED}Bad response from https://$env-$SITE.pantheonsite.io ($response). Recorded in fix-unfreeze-badresponse.log${RESET}"
      fi
    done 
  fi
}

# Loop through the input file.
for site in ${SITES[@]}; do
  restore $site &
done

