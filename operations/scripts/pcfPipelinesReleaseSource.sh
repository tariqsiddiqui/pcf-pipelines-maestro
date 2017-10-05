processPcfPipelinesSourcePatch() {

  configFile="${1}"

  # Executed only when flag is "use-pivnet-release" is set to "true" in configFile config file
  pcfPipelinesSource=$(grep "pcf-pipelines-source" $configFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  # default patch file for "git" option
  patchFile="./operations/opsfiles/replace-pcf-pipelines-git-repo-uri.yml"
  [ "${pcfPipelinesSource,,}" == "pivnet" ] && patchFile="../pcf-pipelines/operations/use-pivnet-release.yml";

  # pre-updates for multiple pipelines style
  preUpdatesForPcfPipelinesSourcePatch "$configFile" "$pcfPipelinesSource" "$patchFile"

  echo "Applying pcf-pipelines source patch for [$pcfPipelinesSource] to upgrade-opsmgr pipelines files."
  for iaasPipeline in ./globalPatchFiles/upgrade-ops-manager/*/pipeline.yml; do
      echo "Patching [$iaasPipeline]"
      cp $iaasPipeline ./upgrade-ops-manager-tmp.yml
      cat ./upgrade-ops-manager-tmp.yml | yaml_patch_linux -o $patchFile > $iaasPipeline
  done

  echo "Applying pcf-pipelines source patch for [$pcfPipelinesSource] to upgrade-tiles pipelines files."
  cp ./globalPatchFiles/upgrade-tile/pipeline.yml ./upgrade-tile-tmp.yml

  cat ./upgrade-tile-tmp.yml | yaml_patch_linux -o $patchFile > ./globalPatchFiles/upgrade-tile/pipeline.yml

  # apply patch to files used for Single Pipeline style (one pipeline with all tiles)
  processPatchForSinglePipelineStyle  "$configFile" "$pcfPipelinesSource"

}

# Pre-patch update options to add version or tag numbers to patch file
preUpdatesForPcfPipelinesSourcePatch() {

  configFile="${1}"
  pcfPipelinesSource="${2}"
  patchFile="${3}"

  pcfpipelinesReleaseOrTag=$(grep "pcf-pipelines-release-or-tag" $configFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")

  if [ "${pcfPipelinesSource,,}" == "git" ]; then

      # if pcfpipelinesReleaseOrTag is commented out, do nothing
      # if pcfpipelinesReleaseOrTag is NOT commented out,
      # then replace "branch: master" with "tag_filter: v..." in the patch file
      if [ -n "$pcfpipelinesReleaseOrTag" ]; then

          echo "Pre-updates of pcf-pipelines git tag for file [$patchFile]."
          sed -i "s/branch: master/tag_filter: \"$pcfpipelinesReleaseOrTag\"/g" $patchFile
      fi
  else
    if [ "${pcfPipelinesSource,,}" == "pivnet" ]; then
      # if pcfpipelinesReleaseOrTag is commented out, issue missing required parameter error
      # if pcfpipelinesReleaseOrTag exists,
      # then replace "product_version: ~" with "product_version: ..." in the patch file
      if [ -n "$pcfpipelinesReleaseOrTag" ]; then
          echo "Pre-updates of pcf-pipelines PivNet version patch for file [$patchFile]."
          sed -i "s/product_version: ~/product_version: \"$pcfpipelinesReleaseOrTag\"/g" $patchFile
      else
          echo "Error in pre-updates of pcf-pipelines PivNet version patch for file [$patchFile]. Required parameter 'pcf-pipelines-release-or-tag' not defined in main config file."
          exit 1
      fi
    fi
  fi


}

processPatchForSinglePipelineStyle() {

  configFile="${1}"
  pcfPipelinesSource="${2}"

  # default patch file for "git" option
  patchFile="./pipelines/utils/single-foundation-pipeline.yml"

  # pre-updates for single pipeline style
  preUpdatesForPcfPipelinesSourcePatch "$configFile" "$pcfPipelinesSource" "$patchFile"

  tagToKeep="PCF-PIPELINES-GIT"
  tagToRemove="PCF-PIPELINES-PIVNET"
  [ "${pcfPipelinesSource,,}" == "pivnet" ] && tagToKeep="PCF-PIPELINES-PIVNET" && tagToRemove="PCF-PIPELINES-GIT";

  # remove marked pivnet specific sections from template patch file
  sed -i "/# ${tagToRemove}+++/,/# ${tagToRemove}---/d" ./pipelines/utils/single-foundation-pipeline.yml
  sed -i "/# ${tagToRemove}+++/,/# ${tagToRemove}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml
  sed -i "/# ${tagToRemove}+++/,/# ${tagToRemove}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-gated-apply-changes.yml
  # remove just markers for the selected option
  sed -i "/# ${tagToKeep}+++/d" ./pipelines/utils/single-foundation-pipeline.yml
  sed -i "/# ${tagToKeep}---/d" ./pipelines/utils/single-foundation-pipeline.yml
  sed -i "/# ${tagToKeep}+++/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml
  sed -i "/# ${tagToKeep}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-upgrade-tile.yml
  sed -i "/# ${tagToKeep}+++/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-gated-apply-changes.yml
  sed -i "/# ${tagToKeep}---/d" ./operations/opsfiles/single-foundation-pipeline/single-pipeline-gated-apply-changes.yml

}
