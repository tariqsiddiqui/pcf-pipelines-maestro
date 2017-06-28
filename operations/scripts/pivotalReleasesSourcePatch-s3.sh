processS3PivotalReleasesSourcePatch() {

  configurationsFile="${1}"
  pivotalReleasesSource="${2}"
  pivotalReleasesSource="${3}"

  # Executed only when flag is "pivotal-releases-source" is set to something other than the default pivnet

  updateS3ResourceParameters "$configurationsFile"
  pcfPipelinesSourceName="pcf-pipelines"
  [ "$pcfPipelinesSource" == "pivnet" ] && pcfPipelinesSourceName="pcf-pipelines-tarball"

  echo "Applying Pivotal Releases source patch for [$pivotalReleasesSource] to upgrade-opsmgr pipelines files."
  for iaasPipeline in ./globalPatchFiles/upgrade-ops-manager/*/pipeline.yml; do
      echo "Patching [$iaasPipeline]"
      filePath=$(dirname $iaasPipeline)
      iaasName=$(echo ${filePath##*/})
      cp $iaasPipeline ./upgrade-ops-manager-tmp.yml
      cp ./operations/opsfiles/use-product-releases-from-s3-opsmgr.yml ./use-product-releases-from-s3-opsmgr-iaas.yml
      removeFileSectionsForIaaSesNotInUse $iaasName ./use-product-releases-from-s3-opsmgr-iaas.yml
      sed -i "s/IAASTYPE/$iaasName/g" ./use-product-releases-from-s3-opsmgr-iaas.yml
      sed -i "s/PCF-PIPELINES-RESOURCE-NAME/$pcfPipelinesSourceName/g" ./use-product-releases-from-s3-opsmgr-iaas.yml
      cat ./upgrade-ops-manager-tmp.yml | yaml_patch_linux -o ./use-product-releases-from-s3-opsmgr-iaas.yml > $iaasPipeline
  done

  echo "Applying Pivotal Releases source patch for [$pivotalReleasesSource] to upgrade-tiles pipelines files."
  cp ./globalPatchFiles/upgrade-tile/pipeline.yml ./upgrade-tile-tmp.yml
  sed -i "s/PCF-PIPELINES-RESOURCE-NAME/$pcfPipelinesSourceName/g" ./operations/opsfiles/use-product-releases-from-s3-tiles.yml
  sed -i "s/PCF-PIPELINES-RESOURCE-NAME/$pcfPipelinesSourceName/g" ./operations/opsfiles/use-product-releases-from-s3-tiles.yml
  cat ./upgrade-tile-tmp.yml | yaml_patch_linux -o ./operations/opsfiles/use-product-releases-from-s3-tiles.yml > ./globalPatchFiles/upgrade-tile/pipeline.yml

  # Generate PivNet to S3 main pipeline
  createPivNetToS3Pipeline "$configurationsFile"

  # apply patch to files used for Single Pipeline style (one pipeline with all tiles)
  processS3PatchForSinglePipelineStyle  "$configFile" "$pivotalReleasesSource"

}

# This function removes parameters from the S3 resource definition templates files
# for the corresponding entries that are commented out in ./common/credentials.yml
updateS3ResourceParameters() {
    configurationsFile="${1}"
    # creates list of optional s3 params to check
    printf "s3-region-name\ns3-endpoint\ns3-disable-ssl\ns3-use-v2-signing\n" > ./s3params.txt
    # iterates through list of s3 params and remove the ones that are commented out from template/patch files
    cat ./s3params.txt | while read s3param
    do
       set +e
       isParamEnabled=$(grep "$s3param" $configurationsFile | grep "^[^#;]" )
       set -e
       if [ -z "${isParamEnabled}" ]; then
         sed -i "/$s3param/d" ./operations/opsfiles/pivnet-to-s3-bucket-opsmgr-entry.yml
         sed -i "/$s3param/d" ./operations/opsfiles/pivnet-to-s3-bucket-tile-entry.yml
         sed -i "/$s3param/d" ./operations/opsfiles/use-product-releases-from-s3-opsmgr.yml
         sed -i "/$s3param/d" ./operations/opsfiles/use-product-releases-from-s3-tiles.yml
         # update files for single pipeline style
         sed -i "/$s3param/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-opsmgr.yml
         sed -i "/$s3param/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml
       fi
    done

}

processS3PatchForSinglePipelineStyle() {

  configFile="${1}"
  pivotalReleasesSource="${2}"

  tagToKeep="PIVOTAL-RELEASES-PIVNET"
  tagToRemove="PIVOTAL-RELEASES-S3"
  [ "${pivotalReleasesSource,,}" == "s3" ] && tagToKeep="PIVOTAL-RELEASES-S3" && tagToRemove="PIVOTAL-RELEASES-PIVNET";

  # remove marked pivnet specific sections from template patch file
  sed -i "/# ${tagToRemove}+++/,/# ${tagToRemove}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-opsmgr.yml
  sed -i "/# ${tagToRemove}+++/,/# ${tagToRemove}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml
  # remove just markers for the selected option
  sed -i "/# ${tagToKeep}+++/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-opsmgr.yml
  sed -i "/# ${tagToKeep}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-opsmgr.yml
  sed -i "/# ${tagToKeep}+++/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml
  sed -i "/# ${tagToKeep}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml

}


createPivNetToS3Pipeline() {
  configurationsFile="${1}"

  templateFoundationFile=$(grep "template-foundation-config-file" "$configurationsFile" | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  if [ -z "${templateFoundationFile}" ]; then
    echo "Error creating the PivNet-to-S3 pipeline. Parameter 'template-foundation-config-file' is missing from /common/credentials.yml"
    exit 1
  fi
  templateFoundationFilePath="./foundations/$templateFoundationFile.yml"
  if [ -e "$templateFoundationFilePath" ]; then
      echo "Generating PivNet-to-S3 pipeline."
      cp ./pipelines/utils/pivnet-to-s3-bucket.yml ./pivnet-to-s3-bucket.yml

      # process opsmgr
      set +e
      opsmgr_product_version=$(grep "BoM_OpsManager_product_version" $templateFoundationFilePath | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
      set -e
      if [ -n "${opsmgr_product_version}" ]; then
          cp ./operations/opsfiles/pivnet-to-s3-bucket-opsmgr-entry.yml ./pivnet-to-s3-bucket-entry.yml
          sed -i "s/PRODUCTVERSION/$opsmgr_product_version/g" ./pivnet-to-s3-bucket-entry.yml

          # determine which IaaSes are used in the foundations files
          determineIaaSesInUse

          # remove IaaS not in use from OpsMgr files download job in Pivnet-To-S3 pipeline operations file
          removeIaaSFromPivnetToS3Pipeline

          echo "Adding OpsManager, version [$opsmgr_product_version] to PivNet-to-S3 pipeline"
          cp ./pivnet-to-s3-bucket.yml ./pivnet-to-s3-bucket-tmp.yml
          cat ./pivnet-to-s3-bucket-tmp.yml | yaml_patch_linux -o ./pivnet-to-s3-bucket-entry.yml > ./pivnet-to-s3-bucket.yml
      else
          echo "No configuration found for Ops Mgr version in the BoM for [$templateFoundationFile], skipping it for the Pivnet-to-S3 pipeline."
      fi
      # process tiles
      set +e
      grep "BoM_tile_" $templateFoundationFilePath | grep "^[^#;]" > ./listOfEnabledTiles.txt
      set -e
      cat ./listOfEnabledTiles.txt | while read tileEntry
      do
        # make a copy of the template file for each tile
        cp ./operations/opsfiles/pivnet-to-s3-bucket-tile-entry.yml ./pivnet-to-s3-bucket-entry.yml

        tileEntryKey=$(echo "$tileEntry" | cut -d ":" -f 1 | tr -d " ")
        tileEntryValue=$(echo "$tileEntry" | cut -d ":" -f 2 | tr -d " ")  # product version
        tile_name=$(echo "$tileEntryKey" | cut -d "_" -f 3)
        tileMetadataFilename="./common/pcf-tiles/$tile_name.yml"

        if [ -e "$tileMetadataFilename" ]; then
          resource_name=$(grep "resource_name" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
          product_slug=$(grep "product_slug" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
          metadata_basename=$(grep "metadata_basename" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")

          sed -i "s/PRODUCTSLUG/$product_slug/g" ./pivnet-to-s3-bucket-entry.yml
          sed -i "s/PRODUCTVERSION/$tileEntryValue/g" ./pivnet-to-s3-bucket-entry.yml
          sed -i "s/PRODUCTEXTENSION/pivotal/g" ./pivnet-to-s3-bucket-entry.yml
          sed -i "s/RESOURCENAME/$resource_name/g" ./pivnet-to-s3-bucket-entry.yml
          sed -i "s/METADATABASENAME/$metadata_basename/g" ./pivnet-to-s3-bucket-entry.yml
          sed -i "s/LISTOFIAAS/$(cat ./listOfIaaSInUse.txt)/g" ./pivnet-to-s3-bucket-entry.yml

          echo "Adding tile [$tile_name], version [$tileEntryValue] to PivNet-to-S3 pipeline"
          cp ./pivnet-to-s3-bucket.yml ./pivnet-to-s3-bucket-tmp.yml
          cat ./pivnet-to-s3-bucket-tmp.yml | yaml_patch_linux -o ./pivnet-to-s3-bucket-entry.yml > ./pivnet-to-s3-bucket.yml
        else
          echo "Error creating the PivNet-to-S3 pipeline. Tile metadata file not found: [$tileMetadataFilename]"
          exit 1
        fi

      done
      # if at least one tile was found, then generate Pivnet-to-S3 pipeline
      if [ -e "./pivnet-to-s3-bucket-entry.yml" ]; then
          cat -n ./pivnet-to-s3-bucket.yml
          echo "Setting Pivnet-to-S3 pipeline."
          ./fly -t "main" set-pipeline -p "pivnet-to-s3-bucket" -c ./pivnet-to-s3-bucket.yml -l "$configurationsFile" -l "$templateFoundationFilePath" -n
      else
          echo "Skipping creation of Pivnet-to-S3 pipeline, no tile configuration found for foundation [$templateFoundationFile]."
      fi

  else
      echo "Error creating the PivNet-to-S3 pipeline. Parameter 'template-foundation-config-file' from /common/credentials.yml points to foundation [$templateFoundationFile], whose config file is not present under /foundations folder."
      exit
  fi
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

removeIaaSFromPivnetToS3Pipeline() {

  # remove IaaS not in use from OpsMgr files download job in Pivnet-To-S3 pipeline operations file

  getListOfAllIaaSProviders    # produces a file with list of all IaaS supported

  # iterate through list of IaaSes and check for presence of env variable maestro_IaaSinUse_${iaasEntry}
  cat ./listOfIaaS.txt | while read iaasLineEntry
  do
      iaasEntry=$(echo "$iaasLineEntry" | cut -d ":" -f 1 | tr -d " ")
      variableName="maestro_IaaSinUse_${iaasEntry}"
      if [ -z "${!variableName}" ]; then
          # IaaS not in use - remove all corresponding sections from operations file
          sed -i "/# ${iaasEntry}+++/,/# ${iaasEntry}---/d" ./pivnet-to-s3-bucket-entry.yml
      else
          # IaaS is in use - remove only corresponding marker lines from operations file
          sed -i "/# ${iaasEntry}+++/d" ./pivnet-to-s3-bucket-entry.yml
          sed -i "/# ${iaasEntry}---/d" ./pivnet-to-s3-bucket-entry.yml
          # set variable with comma-separated list of IaaS in use
          # to be used by other pipelines, e.g. Pivnet-to-s3-bucket
          [ -n "${maestro_listOfIaaSInUse}" ] && export maestro_listOfIaaSInUse="$maestro_listOfIaaSInUse,";
          export maestro_listOfIaaSInUse="${maestro_listOfIaaSInUse}${iaasEntry}"
          echo "$maestro_listOfIaaSInUse" > ./listOfIaaSInUse.txt
      fi
  done
}
