#!/bin/bash

# This script takes an input file of IP addresses and adds them to an ACL on Fastly.
#
# Usage:
# fastly_mass_acl_add.sh FASTLY_API_TOKEN SERVICE_ID ACL_ID

ACTION=DELETE

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

# Check to verify the Fastly API token is valid.

TOKEN_CHECK=`curl -s "https://api.fastly.com/current_customer" -H "Fastly-Key: $FASTLY_API_TOKEN" -H "Accept: application/json" | grep "\"readonly\":false"`

if [[ $TOKEN_CHECK == "" ]] ; then
  echo "Fastly API token invalid."
  exit 1
fi


# Get ACL entries.
ACLS=`curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" -X GET https://api.fastly.com/service/$SERVICE_ID/acl/$ACL_ID/entries | jq -r ' .[] | .id '`

# Loop through entries and delete them.
for acl_entry_id in ${ACLS[@]}; do
  curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" -X DELETE https://api.fastly.com/service/$SERVICE_ID/acl/$ACL_ID/entry/$acl_entry_id
done

