function parseConcourseCredentials() {
  params_file="${1}"
  isMainConfiguration="${2}"
  # get Concourse information and admin credentials
  [ "${isMainConfiguration,,}" == "true" ] && set +e; # allow for failure only for the foundations check
  testIfUrlParamExists=$(grep "concourse_url" $params_file | grep "^[^#;]" | cut -d " " -f 2)
  [ "${isMainConfiguration,,}" == "true" ] && set -e;
  if [ -n "${testIfUrlParamExists}" ]; then
    export cc_url=$testIfUrlParamExists
    export cc_main_user=$(grep "concourse_main_userid" $params_file | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
    export cc_main_pass=$(grep "concourse_main_pass" $params_file | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
    export skip_ssl_verification=$(grep "concourse_skip_ssl_verification" $params_file | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  fi
}

function parseConcourseFoundationCredentials() {
  foundation_params_file="${1}"

  # get Concourse credentials to be used for the Foundation's team
  export cc_user=$(grep "concourse_team_userid" $foundation_params_file | cut -d ":" -f 2 | tr -d " ")
  export cc_pass=$(grep "concourse_team_pass" $foundation_params_file | cut -d ":" -f 2 | tr -d " ")
}

function loginConcourseTeam() {

    concourse_url="${1}"
    userid="${2}"
    passwd="${3}"
    team="${4}"
    skip_ssl_verification="${5}"
    user_auth_params="-u $userid -p $passwd"
    [ "${userid,,}" == "none" ] || [ "${userid,,}" == "changeme" ] && user_auth_params=" ";
    [ "${skip_ssl_verification,,}" == "true" ] && user_auth_params="$user_auth_params -k";
    echo "Performing FLY login to team [$team] of Concourse server $cc_url"
    ./fly -t $team login -c $concourse_url $user_auth_params -n "$team"

}

function createConcourseFoundationTeam() {
  foundation_name="${1}"
  cc_user="${2}"
  cc_pass="${3}"
  admin_team="${4}"

  echo "Setting Concourse team for foundation [$foundation_name]."
  user_auth_params="--basic-auth-username=\"$cc_user\" --basic-auth-password=\"$cc_pass\""
  [ "${cc_user,,}" == "none" ] || [ "${cc_user,,}" == "changeme" ] && user_auth_params=" --no-really-i-dont-want-any-auth ";
  yes | ./fly -t $admin_team set-team -n $foundation_name $user_auth_params

}

function concourseFlySync() {
    current_concourse_url="${1}"
    prev_concourse_url="${2}"
    admin_team="${3}"

    echo "FLY sync"
    if [ -e "./fly" ]; then
        set +e
        [ "$prev_concourse_url" != "$current_concourse_url" ] && echo "Synchronizing FLY..." && ./fly -t $admin_team sync
        set -e
    else
       echo "FLY cli not found"
       exit 1
    fi

}
