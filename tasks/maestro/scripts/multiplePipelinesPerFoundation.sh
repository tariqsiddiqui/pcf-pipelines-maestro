processMultiplePipelinesPerFoundation() {

  foundation="${1}"
  foundationName="${2}"
  iaasType="${3}"
  mainConfigFile="${4}"

  echo "Processing multiple upgrade pipelines for foundation [$foundationName]."

  # ***** Pipeline for Ops-Manager Upgrades ***** (see ./tasks/maestro/scripts/opsmgr.sh)
  setOpsMgrUpgradePipeline "$foundation" "$foundation_name" "$iaasType"
  # ***** Pipeline for PCF Tiles Upgrades ***** (see ./tasks/maestro/scripts/tiles.sh)
  echo "Processing PCF tiles upgrade pipelines for [$foundation_name]"
  setTilesUpgradePipelines "$foundation" "$foundation_name"
  # ***** Pipeline for Buildpack Upgrade ***** (see ./tasks/maestro/scripts/buildpacks.sh)

}
