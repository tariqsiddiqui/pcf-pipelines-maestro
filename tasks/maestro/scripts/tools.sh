function prepareTools() {
    current_concourse_url="${1}"

    # Download fly CLI from concourse server if not done yet
    echo "Downloading FLY from Concourse server $current_concourse_url"
    skipSSLVerificationParameter=" "
    [ "${skip_ssl_verification,,}" == "true" ] && skipSSLVerificationParameter=" --no-check-certificate ";
    wget $skipSSLVerificationParameter -O fly "$current_concourse_url/api/v1/cli?arch=amd64&platform=linux"
    chmod +x ./fly
    echo "FLY version in use:"
    ./fly --version
}

function processDebugEnablementConfig() {

  config_file="${1}"

  set +e
  isDebugEnabled=$(grep "enableDebugMessages" $config_file | grep "^[^#;]" | cut -d " " -f 2)
  set -e
  if [ "${isDebugEnabled,,}" == "true" ]; then
      set -x;
  fi

}
