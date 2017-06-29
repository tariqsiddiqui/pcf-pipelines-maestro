#!/bin/bash -eu

source ./pcf-pipelines-maestro/tasks/maestro/scripts/s3_utils.sh

root=$PWD

product_file="$(ls -1 ${root}/pivnet-product/*.pivotal)"


iaasInUse=$IAAS_TYPE
download_dir="${root}/stemcell"

mkdir -p "$download_dir"

s3RegionName=""
s3DisableSSLCheck="false"
s3v2Signing="false"
s3BucketName="$S3_BUCKET"
[ -n "$S3_DISABLE_SSL" ] && s3DisableSSLCheck="$S3_DISABLE_SSL"
[ -n "$S3_V2" ] && s3v2Signing="$S3_V2"
[ -n "$S3_REGION_NAME" ] && s3RegionName="$S3_REGION_NAME"
[ -n "$S3_ENDPOINT" ] && s3EndPointUrl=$S3_ENDPOINT
[ -z "$S3_ENDPOINT" ] && s3EndPointUrl="s3-$s3RegionName.amazonaws.com" # per http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region

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
