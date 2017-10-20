# This function contains the list of scripts to process pipeline YAML patches for ALL foundations.
# Typically, the execution of these scripts should be controlled by a flag in
# the ./common/credentials file.
processPipelinePatchesForAllFoundations() {

  echo "Global pipeline patches processing."

  echo "Preparing files for all upgrade-ops-manager pipelines"
  mkdir -p ./globalPatchFiles/upgrade-ops-manager
  cp -R ../pcf-pipelines/upgrade-ops-manager/* ./globalPatchFiles/upgrade-ops-manager/.

  echo "Preparing files for upgrade-tile pipelines"
  mkdir -p ./globalPatchFiles/upgrade-tile
  cp ../pcf-pipelines/upgrade-tile/* ./globalPatchFiles/upgrade-tile/.

  # Retrive pcf-pipelines from PivNet release. Controlled by flag pcf-pipelines-source
  processPcfPipelinesSourcePatch "./common/credentials.yml"

  echo "Processing Pivotal Releases source patch"
  processPivotalReleasesSourcePatch "./common/credentials.yml"

}

# This function contains the list of scripts to process pipeline YAML patches for each foundation.
# Typically, the execution of these scripts should be controlled by a flag in
# the foundation configuration file (./foundations/*.yml), which path is provided the "$foundation" variable
processPipelinePatchesPerFoundation() {

  foundation="${1}"
  iaasType="${2}"

  echo "Foundation pipelines patches: preparing template files for upgrade-tile."

  set +e
  opsmgr_product_version=$(grep "BoM_OpsManager_product_version" $foundation | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  set -e
  if [ -n "${opsmgr_product_version}" ]; then
    iaasDirName=$iaasType
    [ "${iaasType,,}" == "google" ] && iaasDirName="gcp"
    cp ./globalPatchFiles/upgrade-ops-manager/$iaasDirName/pipeline.yml ./upgrade-opsmgr.yml
  fi

  # the presence of this file in the maestro root dir is expected by maestro scripts
  cp ./globalPatchFiles/upgrade-tile/pipeline.yml ./upgrade-tile-template.yml

  # *** GATED APPLY CHANGES patch - keep this entry before processUsePivnetReleasePatch ***
  processGatedApplyChangesJobPatch "$foundation" "$iaasType" "./common/credentials.yml"

}

# Generic utility functions for yaml patching
removeTaskFromJob() {

  fileToPatch="${1}"
  parentJobName="${2}"
  taskName="${3}"

  cat > remove_task_from_job.yml <<EOF
---
- op: remove
  path: /jobs/name=$parentJobName/task=$taskName
EOF
  cp $fileToPatch ./removeTaskFromJob-tmp.yml
  cat ./removeTaskFromJob-tmp.yml | yaml_patch_linux -o ./remove_task_from_job.yml > $fileToPatch
}

# applies the maestro resource addition patch to a pipeline
applyMaestroResourcePatch() {
  pipelineFile="${1}"

  cp $pipelineFile ./applyMaestroResourceTmp.yml
  cat ./applyMaestroResourceTmp.yml | yaml_patch_linux -o ./operations/opsfiles/pcf-pipelines-maestro-resource.yml > $pipelineFile

}
