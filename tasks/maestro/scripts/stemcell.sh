function setStemcellAdhocUpgradePipeline() {
  foundation="${1}"
  foundation_name="${2}"

  set +e
  createStemcellPipeline=$(grep "BoM_stemcell_version" $foundation | grep "^[^#;]")
  set -e
  if [ -z "${createStemcellPipeline}" ]; then
      echo "No stemcell upgrade config for [$foundation_name], skipping it."
  else
    stemcell_version=$(grep "BoM_stemcell_version" $foundation | cut -d ":" -f 2 | tr -d " ")
    echo "Setting Stemcell adhoc upgrade pipeline for foundation [$foundation_name], version [$stemcell_version]"
    ./fly -t $foundation_name set-pipeline -p "$foundation_name-Upgrade-Stemcell-Adhoc" -c ./pipelines/utils/stemcell-adhoc-upgrade.yml -l ./common/credentials.yml -l "$foundation" -v "stemcell_version=${stemcell_version}" -n
  fi
}
