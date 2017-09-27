function setOpsMgrUpgradePipeline() {
  foundation="${1}"
  foundation_name="${2}"
  iaasType="${3}"

  set +e
  opsmgr_product_version=$(grep "BoM_OpsManager_product_version" $foundation | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  set -e
  if [ -n "${opsmgr_product_version}" ]; then
      echo "Setting OpsMgr upgrade pipeline for foundation [$foundation_name], version [$opsmgr_product_version]"

      gatedApplyChangesJob=$(grep "gated-Apply-Changes-Job" $foundation | cut -d ":" -f 2 | tr -d " ")
      # if pivotal-releases-source is "s3", then later on avoid adding a duplicate maestro resource to the pipelines
      pivotalReleasesSource=$(grep "pivotal-releases-source" ./common/credentials.yml | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")

      sed -i "s/PRODUCTVERSION/$opsmgr_product_version/g" ./upgrade-opsmgr.yml

      if [ "${pivotalReleasesSource,,}" == "pivnet" ]; then
          echo "Default pipeline, not adding resource for pcf-pipelines-maestro"
      else
          applyMaestroResourcePatch ./upgrade-opsmgr.yml
      fi

      # Pipeline file ./upgrade-opsmgr.yml is produced by processPipelinePatchesPerFoundation() in ./operations/operations.sh
      ./fly -t $foundation_name set-pipeline -p "$foundation_name-Upgrade-OpsMan" -c ./upgrade-opsmgr.yml -l ./common/credentials.yml -l "$foundation" -v "opsman_major_minor_version=${opsmgr_product_version}" -n
  else
      echo "No configuration found for Ops Mgr upgrade pipeline for [$foundation_name], skipping it"
  fi

}
