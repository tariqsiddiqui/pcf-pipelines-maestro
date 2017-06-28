#!/bin/bash -eu

source ./pcf-pipelines-maestro/tasks/maestro/scripts/s3_utils.sh

function main() {
  if [ -z "$IAAS_TYPE" ]; then abort "The required env var IAAS_TYPE was not set"; fi

  local cwd=$PWD
  local download_dir="${cwd}/stemcells"
  local diag_report="${cwd}/diagnostic-report/exported-diagnostic-report.json"

  # get the deduplicated stemcell filename for each deployed release (skipping p-bosh)
  local stemcells=($( (jq --raw-output '.added_products.deployed[] | select (.name | contains("p-bosh") | not) | .stemcell' | sort -u) < "$diag_report"))
  if [ ${#stemcells[@]} -eq 0 ]; then
    echo "No installed products found that require a stemcell"
    exit 0
  fi

  mkdir -p "$download_dir"

  set +e
  s3EndPointUrl=$(grep "s3-endpoint" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d " " -f 2 | tr -d " ")
  s3RegionName=$(grep "s3-region-name" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d ":" -f 2 | cut -d "#" -f 1 | tr -d " ")
  s3DisableSSLCheck=$(grep "s3-disable-ssl" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d ":" -f 2 | cut -d "#" -f 1 | tr -d " ")
  s3v2Signing=$(grep "s3-use-v2-signing" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d ":" -f 2 | cut -d "#" -f 1 | tr -d " ")
  s3BucketName=$S3_BUCKET
  set -e
  [ -z "$s3EndPointUrl" ] && s3EndPointUrl="s3-$s3RegionName.amazonaws.com" # per http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
  [ -z "$s3DisableSSLCheck" ] && s3DisableSSLCheck="false"
  [ -z "$s3v2Signing" ] && s3v2Signing="false"

  setS3CLI "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY" "$s3v2Signing"

  # extract the stemcell version from the filename, e.g. 3312.21, and download the file from pivnet
  for stemcell in "${stemcells[@]}"; do
    local stemcell_version
    stemcell_version=$(echo "$stemcell" | grep -Eo "[0-9]+(\.[0-9]+)?")
    download_stemcell_version_from_s3 $stemcell_version $s3EndPointUrl $s3BucketName $s3DisableSSLCheck $download_dir
  done

  ls -la $download_dir
}

function abort() {
  echo "$1"
  exit 1
}

function download_stemcell_version_from_s3() {
    stemcell_version="$1"
    s3EndPointUrl="$2"
    s3BucketName="$3"
    s3DisableSSLCheck="$4"
    download_dir="$5"
    # check if stemcell file exists
    stemcellFileName=$(stemcellForIaaSExistsInS3 "$stemcell_version" "$IAAS_TYPE" "$s3EndPointUrl" "$s3BucketName" "$s3DisableSSLCheck")

    if [ -n "$stemcellFileName" ]; then
        echo "Downloading stemcell ${stemcell_version} for ${IAAS_TYPE} from S3 repository."
        # download stemcell from S3
        copyFilesFromS3 $s3EndPointUrl "s3://$s3BucketName/stemcells/$IAAS_TYPE/$stemcellFileName" "$download_dir/." $s3DisableSSLCheck "false"
    else
        abort "Could not find stemcell ${stemcell_version} for ${IAAS_TYPE} in S3 repository."
    fi

}

main
