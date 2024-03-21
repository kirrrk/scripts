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
  echo "Restoring $SITE.dev"
  terminus --yes backup:restore -- $SITE.dev >> /tmp/terminus_out 2>&1
  if check_terminus_output $SITE_NAME dev /tmp/terminus_out; then
    echo $SITE >> fix-unfreeze-error.log
    echo "Restore failed on $SITE, likely due to missing codeserver. Logged in fix-unfreeze-error.log"
  else 
    echo "Restoring $SITE.test"
    terminus --yes --quiet backup:restore -- $SITE.test 
    echo "Restoring $SITE.live"
    terminus --yes --quiet backup:restore -- $SITE.live
    echo "Starting second restore on $SITE.dev"
    terminus --yes --quiet backup:restore -- $SITE.dev
    echo "Starting second restore on $SITE.test"
    terminus --yes --quiet backup:restore -- $SITE.test
    echo "Starting second restore on $SITE.live"
    terminus --yes --quiet backup:restore -- $SITE.live 
    sleep 60s
  fi
  
  for env in {dev,test,live} ; do
    response=`curl -I "https://$env-$SITE.pantheonsite.io/" 2> /dev/null | grep HTTP | cut -d" " -f2`
    if [ $response != "200" ] ; then
      echo "https://$env-$SITE.pantheonsite.io" >> fix-unfreeze-badresponse.log
      echo "Bad response from https://$env-$SITE.pantheonsite.io ($response). Recorded in fix-unfreeze-badresponse.log"
    fi
  done 

}

# Loop through the input file.
for site in ${SITES[@]}; do
  restore $site &
done

