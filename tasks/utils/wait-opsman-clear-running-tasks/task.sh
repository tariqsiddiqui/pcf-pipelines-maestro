#!/bin/bash -eu

#This script polls ops mgr waiting for running installs to be empty before beginning
#POLL_INTERVAL controls how quickly the script will poll ops mgr for changes to pending changes/running installs

POLL_INTERVAL=30
function main() {

  local cwd
  cwd="${1}"
  set +e
  while :
  do

      om-linux --target "${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
           --skip-ssl-validation \
           --username "${OPSMAN_USERNAME}" \
           --password "${OPSMAN_PASSWORD}" \
           curl -path /api/v0/installations > running-status.txt

      if [[ $? -ne 0 ]]; then
        echo "Could not login to ops man"
        cat running-status.txt
        exit 1
      fi

      grep "\"status\": \"running\"" running-status.txt
      RUNNING_STATUS=$?

      if [ ${RUNNING_STATUS} -ne 0 ]; then
          echo "No pending changes or running installs detected. Proceeding"
          exit 0
      fi
      echo "Pending changes or running installs detected. Waiting"
      sleep $POLL_INTERVAL
      # To skip waiting on running status on version 1.9.2 (temporary)
      # echo "Validate manually. Skipping automated running status check for 1.9.2 and older. Proceeding"
      # exit 0
  done
	set -e
}

main "${PWD}"
