function setTilesUpgradePipelines() {
  foundation="${1}"
  foundation_name="${2}"

  set +e
  grep "BoM_tile_" $foundation | grep "^[^#;]" > ./listOfEnabledTiles.txt
  set -e

  gatedApplyChangesJob=$(grep "gated-Apply-Changes-Job" $foundation | cut -d ":" -f 2 | tr -d " ")
  # if pivotal-releases-source is "s3", then later on avoid adding a duplicate maestro resource to the pipelines
  pivotalReleasesSource=$(grep "pivotal-releases-source" ./common/credentials.yml | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")

  cat ./listOfEnabledTiles.txt | while read tileEntry
  do
    tileEntryKey=$(echo "$tileEntry" | cut -d ":" -f 1 | tr -d " ")
    tileEntryValue=$(echo "$tileEntry" | cut -d ":" -f 2 | tr -d " ")
    tile_name=$(echo "$tileEntryKey" | cut -d "_" -f 3)
    tileMetadataFilename="./common/pcf-tiles/$tile_name.yml"
    resource_name=$(grep "resource_name" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
    # Pipeline template file ./upgrade-tile-template.yml is produced by processPipelinePatchesPerFoundation() in ./operations/operations.sh
    cp ./upgrade-tile-template.yml ./upgrade-tile.yml
    # update when tile template contains variables to be replaced with sed, e.g. releases in S3 bucket
    resource_name=$(grep "resource_name" $tileMetadataFilename | cut -d ":" -f 2 | tr -d " ")
    sed -i "s/RESOURCENAME/$resource_name/g" ./upgrade-tile.yml
    sed -i "s/PRODUCTVERSION/$tileEntryValue/g" ./upgrade-tile.yml

    # customize upgrade tile job name
    sed -i "s/upgrade-tile/upgrade-$tile_name-tile/g" ./upgrade-tile.yml
    if [ "${gatedApplyChangesJob,,}" == "true" ]; then
        sed -i "s/RESOURCE_NAME_GOES_HERE/$resource_name/g" ./upgrade-tile.yml
        sed -i "s/PREVIOUS_JOB_NAME_GOES_HERE/upgrade-$tile_name-tile/g" ./upgrade-tile.yml
    fi


    if [ "${pivotalReleasesSource,,}" == "pivnet" ] && [ "${gatedApplyChangesJob,,}" == "false" ]; then
        echo "Default pipeline, not adding resource for pcf-pipelines-maestro"
    else
        applyMaestroResourcePatch ./upgrade-tile.yml
    fi

    echo "Setting upgrade pipeline for tile [$tile_name], version [$tileEntryValue]"
    ./fly -t $foundation_name set-pipeline -p "$foundation_name-Upgrade-$tile_name" -c ./upgrade-tile.yml -l "./common/pcf-tiles/$tile_name.yml" -l ./common/credentials.yml -l "$foundation" -v "product_version=${tileEntryValue}" -n
  done

}
