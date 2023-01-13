#!/bin/bash

# The check_terminus_output function below checks a file containing terminus output for "Permission denied (password,publickey)" errors.
#
# Usage:
# To use this function, direct the stderr output of your terminus command to stdout and then use tee to send it to a file, like this:
# terminus drush $SITE_NAME.$SITE_ENV -- status 2>&1 | tee /tmp/terminus_output
#
# Then call the check_terminus_output function and pass it the site name, environment, and output file as arguments, like this:
# check_terminus_output $SITE_NAME $SITE_ENV /tmp/terminus_output
#
# You can also use this function in a script to retry the command when this error is encountered.
#
# Example:
#
#   terminus env:wake $SITE_NAME.$SITE_ENV &>/dev/null
#   terminus drush $SITE_NAME.$SITE_ENV -- status 2>&1 | tee /tmp/terminus_output
#   if check_terminus_output $SITE_NAME $SITE_ENV /tmp/terminus_output; then
#     echo "Encountered Permission denied (password,publickey) error, sleeping for 5 seconds and trying again."
#     sleep 5
#     terminus drush $SITE_NAME.$SITE_ENV -- status
#   fi
#
# Note: This function is intented to help troubleshoot intermittent "Permission denied (password,publickey)" errors.
#       If encountering persistent errors, there is a problem with your ssh key or ssh client.
#       Follow the instructions here to set up your ssh key: https://pantheon.io/docs/ssh-keys
#       Then check the output of 'ssh-add -l' for your key.
#       And check the output of 'ssh -Q key' for 'ssh-rsa'.
#
# To make your life easier, add the following to your ~/.ssh/config file:
#
# Host *.drush.in
#	BatchMode yes
#
# This will cause terminus to error out when presented with a password prompt rather than waiting for your input.
#

check_terminus_output () {
  SITE_NAME=$1
  SITE_ENV=$2
  TERMINUS_OUTPUT=$3
  
  # Checks the terminus output file for "Permission denied (password,publickey).
  if grep -q "Permission denied (password,publickey)" $TERMINUS_OUTPUT; then
    echo
    echo "Permission denied (password,publickey) error encountered."
    
    # Retrieve the site ID and SFTP username to use to get the list of appservers and test the ssh connection.
    SITE_ID=`terminus site:info --format list --field id -- $SITE_NAME`
    SFTP_USERNAME=`terminus connection:info --format list --field sftp_username $SITE_NAME.$SITE_ENV`

    # Use dig to get the list of appservers and then try connecting to each one.
    dig +short -4 appserver.$SITE_ENV.$SITE_ID.drush.in | while read APPSERVER; do
      echo

      # Test ssh connection to appservers to see whether or not the ssh key authentication is working.
      # The ssh command will return "shell request failed" if it IS working.
      # Authentication is not working if a permission denied error is returned.
      echo "Testing connection to appserver: $APPSERVER"
      ssh_output=$( ssh -T -n -oStrictHostKeyChecking=no -oBatchMode=yes -p 2222 $SFTP_USERNAME@$APPSERVER 2>&1)

      if grep -q "shell request failed" <<< "$ssh_output"; then
        echo "Connection to $APPSERVER successful." 
      else
        echo "$APPSERVER connection attempted returned:"
        echo $ssh_output
      fi

    done
    echo 

    # Return in case error is found.
    return
  fi

  # Return false in case error was not found in output file.
  false
}

