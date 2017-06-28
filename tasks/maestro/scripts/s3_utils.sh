function setS3CLI() {
  S3_ACCESS_KEY_ID="${1}"
  S3_SECRET_ACCESS_KEY="${2}"
  s3v2Signing="${3}"

  aws --version
  aws configure set aws_access_key_id $S3_ACCESS_KEY_ID
  aws configure set aws_secret_access_key $S3_SECRET_ACCESS_KEY
  if [ "$s3v2Signing" == "true" ]; then
      aws configure set default.signature_version "v2"
  fi

}

function stemcellForIaaSExistsInS3() {
  stemcell_version="${1}"
  iaasInUse="${2}"
  s3EndPointUrl="${3}"
  s3BucketName="${4}"
  s3DisableSSLCheck="${5}"

  sslCheckString=" "
  [ "$s3DisableSSLCheck" == "true" ] && sslCheckString=" --no-verify-ssl ";

  stemcellNameForIaaS=$(grep "$iaasInUse" ./pcf-pipelines-maestro/common/stemcells-metadata/filename.yml | cut -d ":" -f 2 | tr -d " ")
  stemcellFilename=$(echo $stemcellNameForIaaS | sed "s/(.*)/$stemcell_version/g")
  set +e
  stemcellForIaaSAlreadyUploaded=$(aws s3 ls s3://$s3BucketName/stemcells/$iaasInUse --endpoint-url=$s3EndPointUrl --recursive $sslCheckString | grep "$stemcellFilename")
  set -e
  if [ -n "$stemcellForIaaSAlreadyUploaded" ]; then
    echo "$stemcellFilename"
  else
    echo ""
  fi
}

function copyFilesFromS3() {
  s3EndPointUrl="${1}"
  sourceBucketAndFilesPath="${2}"
  download_dir="${3}"
  s3DisableSSLCheck="${4}"
  isRecursive="${5}"

  sslCheckString=" "
  recursiveString=" "
  [ "$s3DisableSSLCheck" == "true" ] && sslCheckString=" --no-verify-ssl ";
  [ "$isRecursive" == "true" ] && recursiveString=" --recursive ";

  aws s3 cp $sourceBucketAndFilesPath $download_dir --endpoint-url=$s3EndPointUrl $recursiveString $sslCheckString

}

function moveFilesToS3() {
  s3EndPointUrl="${1}"
  sourceLocalPath="${2}"
  destinationBucketPath="${3}"
  s3DisableSSLCheck="${4}"
  isRecursive="${5}"

  sslCheckString=" "
  recursiveString=" "
  [ "$s3DisableSSLCheck" == "true" ] && sslCheckString=" --no-verify-ssl ";
  [ "$isRecursive" == "true" ] && recursiveString=" --recursive ";
  aws s3 mv $sourceLocalPath $destinationBucketPath --endpoint-url=$s3EndPointUrl $recursiveString $sslCheckString

}
