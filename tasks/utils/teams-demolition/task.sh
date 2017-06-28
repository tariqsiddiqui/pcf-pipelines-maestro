#!/bin/bash
# This script deletes ALL corresponding Concourse teams for all foundations under the "foundations" directory
# This is mostly used for testing purposes of the Maestro pipeline
set -e

cd ./pcf-pipelines-maestro

source ./tasks/maestro/scripts/concourse.sh
source ./tasks/maestro/scripts/tools.sh

previous_concourse_url=""

export cc_url=""
export cc_main_user=""
export cc_main_pass=""
export cc_user=""
export cc_pass=""


for foundation in ./foundations/*.yml; do

    # parse foundation name
    foundation_fullname=$(basename "$foundation")
    foundation_name="${foundation_fullname%.*}"
    echo "Processing team deletion for foundation [$foundation_name]"

    parseConcourseCredentials "./common/credentials.yml" "true" 

    prepareTools "$cc_url" "$previous_concourse_url"

    previous_concourse_url=$cc_url

    loginConcourseTeam "$cc_url" "$cc_main_user" "$cc_main_pass" "main"

    echo "Processing deletion of team $foundation_name"
    set +e
    team_existence=$(./fly -t main teams | grep $foundation_name)
    set -e
    if [ -z "${team_existence}" ]; then
      echo "Team $foundation_name does not exist, skipping deletion."
    else
      echo "Deleting team $foundation_name"
      echo "$foundation_name" | ./fly -t main destroy-team -n "$foundation_name"
    fi

done
