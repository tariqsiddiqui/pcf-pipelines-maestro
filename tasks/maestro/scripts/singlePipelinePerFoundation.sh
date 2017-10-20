processSinglePipelinePerFoundation() {

  foundation="${1}"
  foundationName="${2}"
  iaasType="${3}"
  mainConfigFile="${4}"

  echo "Processing a single upgrade pipeline for foundation [$foundationName]"

  pcfPipelinesSource=$(grep "pcf-pipelines-source" $mainConfigFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")

  # gatedApplyChangesJob=$(grep "gated-Apply-Changes-Job" $foundation | cut -d ":" -f 2 | tr -d " ")

  # if pivotal-releases-source is "s3", then later on avoid adding a duplicate maestro resource to the pipelines
  pivotalReleasesSource=$(grep "pivotal-releases-source" $mainConfigFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")

  # prepare template patch file for all pipelines
  cp ./pipelines/utils/single-foundation-pipeline.yml ./singleUpgradePipeline.yml
  sed -i "s/FOUNDATION-NAME/$foundationName/g" ./singleUpgradePipeline.yml

  # prepare patch file for the "All" jobs Group section of the pipeline
  primeAllJobsGroupSection

  # add upgrade pipelines for Ops Mgr if enabled in the BoM
  singlePipelineProcessOpsMgr "$foundation" "$iaasType" "$gatedApplyChangesJob" "$pivotalReleasesSource"

  # add upgrade pipelines for the enabled tiles in the BoM
  singlePipelineProcessTiles "$foundation" "$iaasType" "$gatedApplyChangesJob"

#      gatedApplyChangesPatchUpdatePcfPipelinesSource "./operations/opsfiles/single-foundation-pipeline/single-pipeline-gated-apply-changes.yml" "$pcfPipelinesSource"

      cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
      cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o ./operations/opsfiles/single-foundation-pipeline/single-pipeline-gated-apply-changes.yml > ./singleUpgradePipeline.yml
      cat > tile-group-entry.yml <<EOF
---
- op: add
  path: /groups/-
  value:
    name: Apply-Changes
    jobs:
    - apply-changes
EOF
      cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
      cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o tile-group-entry.yml > ./singleUpgradePipeline.yml
      echo "    - apply-changes" >> all-jobs-group-entry.yml

  # fi

  # apply patches to include the updated "All" group to the pipeline file
  cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
  cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o all-jobs-group-entry.yml > ./singleUpgradePipeline.yml

  # create single PCF upgrade pipeline
  ./fly -t $foundation_name set-pipeline -p "$foundation_name-Upgrades" -c ./singleUpgradePipeline.yml -l "$mainConfigFile" -l "$foundation" -n
}

# Add upgrade OpsMgr job to the pipeline
singlePipelineProcessOpsMgr() {
  foundation="${1}"
  iaasType="${2}"
  gatedApplyChangesJob="${3}"
  pivotalReleasesSource="${4}"

  # check if Ops-Mgr upgrade pipeline is enabled in the BoM
  set +e
  opsmgr_product_version=$(grep "BoM_OpsManager_product_version" $foundation | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  set -e
  if [ -n "${opsmgr_product_version}" ]; then
      echo "Setting OpsMgr upgrade pipeline for foundation [$foundation_name], version [$opsmgr_product_version]"

      iaasDirName=$iaasType
      [ "${iaasType,,}" == "google" ] && iaasDirName="gcp"

      cp ./globalPatchFiles/upgrade-ops-manager/$iaasDirName/pipeline.yml ./upgrade-opsmgr-original-global-patched.yml
      # check if gatedApplyChangesJob is enabled and process it appropriately for opsmgr template file

      # [ "${gatedApplyChangesJob,,}" == "true" ] && removeTaskFromJob "./upgrade-opsmgr-original-global-patched.yml" "upgrade-opsmgr" "apply-changes"

      cp ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-opsmgr.yml ./single-pipeline-upgrade-opsmgr-patch.yml
      sed -i "s/PRODUCTVERSION/$opsmgr_product_version/g" ./single-pipeline-upgrade-opsmgr-patch.yml

      # prepare upgrade pipeline file and append it to patch file
      # from the original pcf-pipelines Ops-Mgr upgrade pipeline, isolate the upgrade-opsmgr job
      echo "  name: upgrade-opsmgr" > ./upgrade-opsmgr-single-template.yml
      sed "1,/- name: upgrade-opsmgr/d" ./upgrade-opsmgr-original-global-patched.yml >> ./upgrade-opsmgr-single-template.yml
      # remove reference to regulator job, which is not added to the single pipeline
      sed -i "s/passed:/passed: []/" ./upgrade-opsmgr-single-template.yml
      sed -i "/- regulator/d" ./upgrade-opsmgr-single-template.yml
      # indent all lines of updated file with two spaces
      sed -i -e "s/^/  /" ./upgrade-opsmgr-single-template.yml

      applyMaestroResourcePatch ./upgrade-tile-template.yml;

      # append upgrade-opsmgr job to patch file
      cat ./upgrade-opsmgr-single-template.yml >> ./single-pipeline-upgrade-opsmgr-patch.yml

      pcfPipelinesResourceKey="pcf-pipelines"
      [ "${pcfPipelinesSource,,}" == "pivnet" ] && pcfPipelinesResourceKey="pcf-pipelines-tarball";


      if [ "${pivotalReleasesSource,,}" == "pivnet" ]; then  # default, add pcf-pipelines-maestro
          # append patch to add dependency on maestro job and maestro resource
          cat >> ./single-pipeline-upgrade-opsmgr-patch.yml <<EOF
- op: replace
  path: /jobs/name=upgrade-opsmgr/get=$pcfPipelinesResourceKey
  value:
    do:
    - get: $pcfPipelinesResourceKey
    - get: pcf-pipelines-maestro
      trigger: false
      passed: [maestro-timer]
EOF
      else   # pcf-pipelines-maestro entry already exists from s3 patch, just add trigger:true and "passed"
        cat >> ./single-pipeline-upgrade-opsmgr-patch.yml <<EOF
- op: replace
  path: /jobs/name=upgrade-opsmgr/get=pcf-pipelines-maestro
  value:
   get: pcf-pipelines-maestro
   trigger: true
   passed: [maestro-timer]
EOF
      fi

      # apply ops-mgr pipeline patch to main pipeline
      cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
      cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o ./single-pipeline-upgrade-opsmgr-patch.yml > ./singleUpgradePipeline.yml

      echo "    - upgrade-opsmgr" >> all-jobs-group-entry.yml
      # create a group section for the specific tile
      cat > tile-group-entry.yml <<EOF
---
- op: add
  path: /groups/-
  value:
    name: Ops-Manager
    jobs:
    - maestro-timer
    - upgrade-opsmgr
EOF
      cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
      cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o tile-group-entry.yml > ./singleUpgradePipeline.yml

  else
      echo "No configuration found for Ops Mgr upgrade pipeline for [$foundation_name], skipping it"
  fi

}

# Add upgrade tiles jobs to the pipeline
singlePipelineProcessTiles() {
  foundation="${1}"
  iaasType="${2}"
  gatedApplyChangesJob="${3}"

  set +e
  grep "BoM_tile_" $foundation | grep "^[^#;]" > ./listOfEnabledTiles.txt
  set -e
  # iterate through list of enabled tiles from the BoM
  cat ./listOfEnabledTiles.txt | while read tileEntry
  do

    tileEntryKey=$(echo "$tileEntry" | cut -d ":" -f 1 | tr -d " ")
    tileEntryValue=$(echo "$tileEntry" | cut -d ":" -f 2 | tr -d " ")
    tile_name=$(echo "$tileEntryKey" | cut -d "_" -f 3)
    resource_name=$(grep "resource_name" ./common/pcf-tiles/$tile_name.yml | cut -d ":" -f 2 | tr -d " ")

    # Prepare patch template file for the specific tile
    cp ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml ./single-pipeline-upgrade-tile.yml
    # check if gatedApplyChangesJob is enabled and process it appropriately for opsmgr template file
    #[ "${gatedApplyChangesJob,,}" == "true" ] && sed -i "/NON-GATED-APPLY-CHANGES+++/,/NON-GATED-APPLY-CHANGES---/d" ./single-pipeline-upgrade-tile.yml

    # get tile metadata file
    tileMetadataFilename="./common/pcf-tiles/$tile_name.yml"

    if [ -e "$tileMetadataFilename" ]; then
      # retrieve tile metadata from tile file
      resource_name=$(grep "resource_name" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
      product_name=$(grep "product_name" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
      product_slug=$(grep "product_slug" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
      metadata_basename=$product_slug
      # replace product name, version, metadata, resource for the tile in the template
      sed -i "s/RESOURCE_NAME_GOES_HERE/$tile_name/g" ./single-pipeline-upgrade-tile.yml
      sed -i "s/PRODUCTSLUG/$product_slug/g" ./single-pipeline-upgrade-tile.yml
      sed -i "s/PRODUCTVERSION/$tileEntryValue/g" ./single-pipeline-upgrade-tile.yml
      sed -i "s/PRODUCTMETADATANAME/$metadata_basename/g" ./single-pipeline-upgrade-tile.yml
      sed -i "s/PRODUCTNAME/$product_name/g" ./single-pipeline-upgrade-tile.yml
    else
      echo "Error creating the PivNet-to-S3 pipeline. Tile metadata file not found: [$tileMetadataFilename]"
      exit 1
    fi


    # apply patch to add tile jobs to pipeline
    cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
    cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o ./single-pipeline-upgrade-tile.yml > ./singleUpgradePipeline.yml

    # create a group section for the specific tile
    cat > tile-group-entry.yml <<EOF
---
- op: add
  path: /groups/-
  value:
    name: $tile_name
    jobs:
    - maestro-timer
    - upload-and-stage-$tile_name-tile
EOF
    cp  ./singleUpgradePipeline.yml ./singleUpgradePipeline-tmp.yml
    cat ./singleUpgradePipeline-tmp.yml | yaml_patch_linux -o tile-group-entry.yml > ./singleUpgradePipeline.yml
    echo "    - upload-and-stage-$tile_name-tile" >> all-jobs-group-entry.yml

  done

}

# Prepare patch file for the Group section for All jobs
primeAllJobsGroupSection() {

  cat > all-jobs-group-entry.yml <<EOF
---
- op: replace
  path: /groups/name=All
  value:
    name: All
    jobs:
    - maestro-timer
EOF

}
