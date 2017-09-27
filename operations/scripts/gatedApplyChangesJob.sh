processGatedApplyChangesJobPatch() {

  foundation="${1}"
  iaasType="${2}"
  mainConfigFile="${3}"



  gatedApplyChangesJob=$(grep "gated-Apply-Changes-Job" $foundation | cut -d ":" -f 2 | tr -d " ")
  if [ "${gatedApplyChangesJob,,}" == "true" ]; then

      # if pcf-pipelines source is "pivnet" then, later on, patch pipeline appropriately with ./operations/opsfiles/gated-apply-changes-pivnet.yml
      pcfPipelinesSource=$(grep "pcf-pipelines-source" $mainConfigFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")


      # Gated apply changes removed for OpsMgr upgrade since OpsMgr VM is already replaced by the time that Apply Changes is invoked
      # so it makes sense for that step to be executed in-line with all other steps of that pipeline and not be gated.

      # echo "Applying Gated Apply Changes job patch to upgrade-opsmgr pipeline file."
      # cp ./upgrade-opsmgr.yml ./upgrade-opsmgr-tmp.yml
      # cp ./operations/opsfiles/gated-apply-changes.yml ./gated_apply_changes-opsmgr.yml
      # remove marked sections for pcf-pipelines source from template patch file
      # gatedApplyChangesPatchUpdatePcfPipelinesSource "./gated_apply_changes-opsmgr.yml" "$pcfPipelinesSource"
      # sed -i "s/RESOURCE_NAME_GOES_HERE/pivnet-opsmgr/g" ./gated_apply_changes-opsmgr.yml
      # sed -i "s/MAIN_JOB_NAME_GOES_HERE/upgrade-opsmgr/g" ./gated_apply_changes-opsmgr.yml
      # sed -i "s/PREVIOUS_JOB_NAME_GOES_HERE/upgrade-opsmgr/g" ./gated_apply_changes-opsmgr.yml
      # cat ./upgrade-opsmgr-tmp.yml | yaml_patch_linux -o ./gated_apply_changes-opsmgr.yml > ./upgrade-opsmgr.yml

      cp ./upgrade-tile-template.yml ./upgrade-tile-tmp.yml

      # echo "Processing Gated Apply Changes job patch to upgrade-tile pipeline template - removing wait_for_opsman task."
      # removeTaskFromJob "./upgrade-tile-tmp.yml" "upgrade-tile" "wait-opsman-clear"

      echo "Applying Gated Apply Changes job patch to upgrade-tile pipeline template."
      cp ./operations/opsfiles/gated-apply-changes.yml ./gated_apply_changes-tiles.yml
      # remove marked sections for pcf-pipelines source from template patch file
      gatedApplyChangesPatchUpdatePcfPipelinesSource "./gated_apply_changes-tiles.yml" "$pcfPipelinesSource"
      # sed -i "s/MAIN_JOB_NAME_GOES_HERE/upgrade-tile/g" ./gated_apply_changes-tiles.yml
      cat ./upgrade-tile-tmp.yml | yaml_patch_linux -o ./gated_apply_changes-tiles.yml > ./upgrade-tile-template.yml

      # remove marked sections for pcf-pipelines source from template patch file
      gatedApplyChangesPatchUpdatePcfPipelinesSource "./upgrade-tile-template.yml" "$pcfPipelinesSource"

  fi
}

gatedApplyChangesPatchUpdatePcfPipelinesSource() {
  # remove marked sections for pcf-pipelines source from template patch file

  fileToPatch="${1}"
  pcfPipelinesSource="${2}"
  tagToKeep="PCF-PIPELINES-GIT"
  tagToRemove="PCF-PIPELINES-PIVNET"
  [ "${pcfPipelinesSource,,}" == "pivnet" ] && tagToKeep="PCF-PIPELINES-PIVNET" && tagToRemove="PCF-PIPELINES-GIT";
  sed -i "/# ${tagToRemove}+++/,/# ${tagToRemove}---/d" $fileToPatch
  sed -i "/# ${tagToKeep}+++/d" $fileToPatch
  sed -i "/# ${tagToKeep}---/d" $fileToPatch
}
