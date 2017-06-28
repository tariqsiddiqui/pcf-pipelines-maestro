#!/bin/bash -eu

source ./pcf-pipelines-maestro/tasks/maestro/scripts/s3_utils.sh

stemcell_version=$(cat ./s3-stemcell-info/*_stemcell_version.txt)
echo "Processing stemcell upload to S3 for version [$stemcell_version]"

# iterate through list of IaaS in use
export listOfIaaSInUse="$LIST_OF_IAAS"  # comma separated list
echo "List of IaaS instances in use: $listOfIaaSInUse"

set +e
s3EndPointUrl=$(grep "s3-endpoint" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d " " -f 2 | tr -d " ")
s3RegionName=$S3_REGION
s3DisableSSLCheck=$(grep "s3-disable-ssl" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d ":" -f 2 | cut -d "#" -f 1 | tr -d " ")
s3v2Signing=$(grep "s3-use-v2-signing" $MAIN_CONFIG_FILE | grep "^[^#;]" | cut -d ":" -f 2 | cut -d "#" -f 1 | tr -d " ")
s3BucketName=$S3_BUCKET
set -e
[ -z "$s3EndPointUrl" ] && s3EndPointUrl="s3-$s3RegionName.amazonaws.com" # per http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
[ -z "$s3DisableSSLCheck" ] && s3DisableSSLCheck="false"
[ -z "$s3v2Signing" ] && s3v2Signing="false"

setS3CLI "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY" "$s3v2Signing"

# iterate through comma-separated list of IaaSes
for iaasInUse in ${listOfIaaSInUse//,/ }
do
    firstTimePivNetCheckDone=""
    # check if stemcell version already exist in S3 for the IaaS
    stemcellForIaaSAlreadyUploaded=$(stemcellForIaaSExistsInS3 "$stemcell_version" "$iaasInUse" "$s3EndPointUrl" "$s3BucketName" "$s3DisableSSLCheck")
    echo "Checking if stemcell version [$stemcell_version] for [$iaasInUse] already exists on S3"
    if [ -z "$stemcellForIaaSAlreadyUploaded" ]; then
        echo "Stemcell version [$stemcell_version] for [$iaasInUse] does not yet exist on S3"
        if [ -z "$firstTimePivNetCheckDone" ]; then
            echo "Logging in to PivNet"
            pivnet-cli login --api-token="$PIVNET_TOKEN"
            pivnet-cli eula --eula-slug=pivotal_software_eula >/dev/null
            echo "Checking if stemcell version exists in PivNet"
            # ensure the stemcell version found in the manifest exists on pivnet
            if [[ $(pivnet-cli pfs -p stemcells -r "$stemcell_version") == *"release not found"* ]]; then
              abort "Could not find the required stemcell version ${stemcell_version}. This version might not be published on PivNet yet, try again later."
              exit 1
            fi
            firstTimePivNetCheckDone="true"
        fi

        # loop over all the stemcells for the specified version and then download it if it's for the IaaS we're targeting
        for product_file_id in $(pivnet-cli pfs -p stemcells -r "$stemcell_version" --format json | jq .[].id); do
          product_file_name=$(pivnet-cli product-file -p stemcells -r "$stemcell_version" -i "$product_file_id" --format=json | jq .name)
          iaasStringToSearch=${iaasInUse}
          [ "${iaasInUse}" == "gcp" ] && iaasStringToSearch="google";  # address custom rule for GCP stemcell name vs IaaS IDs
          if echo "$product_file_name" | grep -iq "$iaasStringToSearch"; then
            mkdir -p "./stemcells/${iaasInUse}"
            cd "./stemcells/${iaasInUse}"
            pivnet-cli download-product-files -p stemcells -r "$stemcell_version" -i "$product_file_id" -d "." --accept-eula
            # upload stemcell to S3
            cd ..
            echo "Uploading stemcell version [$stemcell_version] for [$iaasInUse] to S3."
            moveFilesToS3 $s3EndPointUrl "." "s3://$s3BucketName/stemcells" "$s3DisableSSLCheck" "true"
            echo "Stemcell version [$stemcell_version] for [$iaasInUse] uploaded to S3."
            cd ..
          fi
        done
    else
      echo "Stemcell version [$stemcell_version] for [$iaasInUse] already exists on S3, skipping its upload."
    fi
done
