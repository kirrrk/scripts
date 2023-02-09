#!/bin/bash

# This script takes an input file of IP addresses and adds them to an ACL on Fastly.
#
# Usage:
# fastly_mass_acl_add.sh FASTLY_API_TOKEN SERVICE_ID ACL_ID TICKET_NUMBER INPUT_FILE

ACTION=POST

# Checks for required input or prompts for it.

if [ "$1" ]; then
  FASTLY_API_TOKEN=$1
else
  echo "Fastly API token: "
  read FASTLY_API_TOKEN
fi

if [ "$2" ]; then
  SERVICE_ID=$2
else
  echo "Service ID: "
  read SERVICE_ID
fi

if [ "$3" ]; then
  ACL_ID=$3
else
  echo "ACL ID: "
  read ACL_ID
fi

if [ "$4" ]; then
  TICKET_NUMBER=$4
else
  echo "Ticket number: "
  read TICKET_NUMBER
fi

if [ "$5" ]; then
  INPUT_FILE=$5
else
  echo "Input file: "
  read INPUT_FILE
fi

if [[ "$@" == *" -d"* ]]; then
  ACTION=DELETE
fi

# Check to see if the input file exists.

if [[ ! -f $INPUT_FILE ]]; then
  echo "Input file not found."
  exit
else

  # Check to see if the input file contains more than 1000 lines.
  if [[ `cat $INPUT_FILE | wc -l` -gt 1000 ]] ; then
    echo "Input file contains over 1000 entries. Fastly's ACLs have a maximum limit of 1000 entries. Do you want to continue? (y/n) "
    CONTINUE="n"
    read CONTINUE
    if [ "$CONTINUE" != "y" ] ; then
      exit
    fi 
  fi

  IPS=`cat $INPUT_FILE`
fi

# Check to verify the Fastly API token is valid.

TOKEN_CHECK=`curl -s "https://api.fastly.com/current_customer" -H "Fastly-Key: $FASTLY_API_TOKEN" -H "Accept: application/json" | grep "\"readonly\":false"`

if [[ $TOKEN_CHECK == "" ]] ; then
  echo "Fastly API token invalid."
  exit
fi

# Loop through the input file.

for ip in ${IPS[@]}; do

# Verify the IP address is valid.
  if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

    if [[ $ACTION == "POST" ]] ; then 
      curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" -X $ACTION https://api.fastly.com/service/$SERVICE_ID/acl/$ACL_ID/entry -d "ip=$ip&negated=0&comment=$TICKET_NUMBER" 
    elif
      echo "Only creating entries has been implemented in this script. Exiting."
      exit
    fi

else
    echo "Skipping invalid IP: $ip"
  fi

done

