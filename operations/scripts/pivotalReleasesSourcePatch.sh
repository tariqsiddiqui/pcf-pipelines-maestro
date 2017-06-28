processPivotalReleasesSourcePatch() {

  configurationsFile="${1}"


  # Executed only when flag is "pivotal-releases-source" is set to something other than the default pivnet
  pivotalReleasesSource=$(grep "pivotal-releases-source" "$configurationsFile" | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  pcfPipelinesSource=$(grep "pcf-pipelines-source" $configurationsFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")

  echo "Processing Pivotal Releases source customization. [$pivotalReleasesSource]"
  if [ "${pivotalReleasesSource,,}" == "s3" ]; then
    processS3PivotalReleasesSourcePatch $configurationsFile $pivotalReleasesSource $pcfPipelinesSource
  else
    if [ "${pivotalReleasesSource,,}" == "artifactory" ]; then
      processArtifactoryPivotalReleasesSourcePatch $configurationsFile $pivotalReleasesSource $pcfPipelinesSource
    fi
  fi
  # apply patch to files used for Single Pipeline style (one pipeline with all tiles)
  processS3PatchForSinglePipelineStyle  "$configFile" "$pivotalReleasesSource"

}


determineIaaSesInUse() {
  # determine which IaaSes are used in the foundations files
  # iterates through foundations config files and creates env variables for the corresponding IaaS
  for foundation in ./foundations/*.yml; do
      iaasInUse=$(grep "iaas_type" $foundation | cut -d ":" -f 2 | tr -d " ")
      variableName="maestro_IaaSinUse_${iaasInUse}"
      export "${variableName}"="true"
  done
}


removeFileSectionsForIaaSesNotInUse() {
  iaasInUse="${1}"
  fileName="${2}"

  getListOfAllIaaSProviders   # produces a file with list of all IaaS supported

  # iterate through list of IaaSes
  cat ./listOfIaaS.txt | while read iaasLineEntry
  do
      iaasEntry=$(echo "$iaasLineEntry" | cut -d ":" -f 1 | tr -d " ")
      if [ "$iaasEntry" != "$iaasInUse" ]; then
          # IaaS not in use - remove all corresponding sections from file
          sed -i "/# ${iaasEntry}+++/,/# ${iaasEntry}---/d" $fileName
      else
          # IaaS is in use - remove only corresponding marker lines to clean up file
          sed -i "/# ${iaasEntry}+++/d" $fileName
          sed -i "/# ${iaasEntry}---/d" $fileName
      fi
  done

}

getListOfAllIaaSProviders() {

  # get list of IaaSes from ops-mgr metadata file
  set +e
  grep -v -e '^[[:space:]]*$' ./common/opsmgr-metadata/globs.yml | grep "^[^#;]" > ./listOfIaaS.txt
  set -e

}
