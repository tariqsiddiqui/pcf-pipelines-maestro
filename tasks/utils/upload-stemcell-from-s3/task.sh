#!/bin/bash -eu

source ./pcf-pipelines-maestro/tasks/maestro/scripts/s3_utils.sh

root=$PWD

product_file="$(ls -1 ${root}/pivnet-product/*.pivotal)"


iaasInUse=$IAAS_TYPE
download_dir="${root}/stemcell"

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

# get info about required stemcell version for product from s3 repository
stemcell_version=$(cat s3-product-stemcell-info/*_stemcell_version.txt)

# check if stemcell version already exist in S3 for the IaaS
stemcellFileName=$(stemcellForIaaSExistsInS3 "$stemcell_version" "$iaasInUse" "$s3EndPointUrl" "$s3BucketName" "$s3DisableSSLCheck")
echo "Checking if stemcell version [$stemcell_version] for [$iaasInUse] already exists on S3"
if [ -n "$stemcellFileName" ]; then
    echo "Downloading stemcell ${stemcell_version} for ${iaasInUse} from S3 repository."
    # download stemcell from S3
    copyFilesFromS3 $s3EndPointUrl "s3://$s3BucketName/stemcells/$iaasInUse/$stemcellFileName" "$download_dir/." $s3DisableSSLCheck "false"
else
     echo "Error. Stemcell version [$stemcell_version] for [$iaasInUse] does not yet exist on S3!!"
     exit 1
fi

stemcell="$(ls -1 "${download_dir}"/*.tgz)"

om-linux --target "https://${OPSMAN_URI}" \
  --skip-ssl-validation \
  --username "${OPSMAN_USERNAME}" \
  --password "${OPSMAN_PASSWORD}" \
  upload-stemcell \
  --stemcell "${stemcell}"
