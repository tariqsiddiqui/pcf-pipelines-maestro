function setBuildpacksUpgradePipelines() {

  foundation="${1}"
  foundation_name="${2}"

  set +e
  grep "BoM_bp_" $foundation | grep "^[^#;]" > ./listOfEnabledBuildpacks.txt
  set -e
  previousBPName=""
  previousBPVersion=""
  previousBPEntryKey=""
  cp ./pipelines/utils/buildpack-upgrade.yml ./buildpack-upgrade.yml
  cat ./listOfEnabledBuildpacks.txt | while read bpEntry
  do
    bpEntryKey=$(echo "$bpEntry" | cut -d ":" -f 1 | tr -d " ")
    bpEntryValue=$(echo "$bpEntry" | cut -d ":" -f 2 | tr -d " ")
    bpName=${bpEntryKey:7}         # remove prefix "BoM_bp_"
    baseBpName=${bpName%_*}            # remove suffix "_current" or "_candidate"

    if [ -z "${previousBPName}" ]; then
        previousBPName=$bpName
        previousBPVersion=$bpEntryValue
        previousBPEntryKey=$bpEntryKey
        echo "Found entry for [$bpName], version [$bpEntryValue], looking for complementary entry."
    else
        if [ "${previousBPName%_*}" != "${bpName%_*}" ]; then   # check if base names of buildpack match from the two entries
            echo "Task could not find two matching entries for buildpack ${bpName%_*}. Failing."
            exit 1
        else
            echo "Adding parameters for [$previousBPName,$previousBPVersion] to yaml patch file."
            sed "s/BP_NAME_CANDIDATE/$previousBPName/g" ./operations/opsfiles/buildpack-entry-template.yml > ./tmpBuildpackPatch.yml
            sed -i "s/BP_VERSION_PARAM_NAME_CANDIDATE/$previousBPEntryKey/g" ./tmpBuildpackPatch.yml
            echo "Adding parameters for [$bpName,$bpEntryValue] to yaml patch file."
            sed -i "s/BP_NAME_CURRENT/$bpName/g" ./tmpBuildpackPatch.yml
            sed -i "s/BP_VERSION_PARAM_NAME_CURRENT/$bpEntryKey/g" ./tmpBuildpackPatch.yml
            sed -i "s/BP_VERSION_PARAM_NAME_CURRENT/$bpEntryKey/g" ./tmpBuildpackPatch.yml
            echo "Using Yaml Patch tool to add entries for custom buildpacks of [${bpName%_*}]"
            cat ./buildpack-upgrade.yml | yaml_patch_linux -o ./tmpBuildpackPatch.yml > ./buildpack-upgrade-final.yml
            # check if buildpack requires globs parameters
            set +e
            buildpackGlobs=$(grep "$baseBpName:" ./common/buildpacks-metadata/globs.yml | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
            set -e
            if [ -z "${buildpackGlobs}" ]; then
                echo "No globs config found for buildpack [$baseBpName]"
                cp ./buildpack-upgrade-final.yml ./buildpack-upgrade.yml
            else
                echo "Applying globs config for buildpack [$baseBpName]"
                cp ./operations/opsfiles/buildpack-globs-entries.yml ./add-buildpack-globs.yml
                sed -i "s/BP_NAME_CURRENT/$bpName/g" ./add-buildpack-globs.yml
                sed -i "s/BP_NAME_CANDIDATE/$previousBPName/g" ./add-buildpack-globs.yml
                sed -i "s/BP_GLOBS/$buildpackGlobs/g" ./add-buildpack-globs.yml
                cat ./buildpack-upgrade-final.yml | yaml_patch_linux -o ./add-buildpack-globs.yml > ./buildpack-upgrade.yml
            fi
            previousBPName=""
            previousBPVersion=""
            previousBPEntryKey=""
        fi
    fi

  done
  if [ -z "${previousBPName}" ]; then
      if [ -f "./tmpBuildpackPatch.yml" ]; then
          echo "Setting buildpack upgrade pipelines for foundation [$foundation_name]"
          sed -i "s/- name\: placeholder/ /g" ./buildpack-upgrade-final.yml
          ./fly -t $foundation_name set-pipeline -p "$foundation_name-Upgrade-Buildpacks" -c ./buildpack-upgrade-final.yml -l ./common/credentials.yml -l "$foundation" -n
      else
          echo "No buildpack entry found for foundation [$foundation_name]. Skiping step."
      fi
  else
      echo "Task could not find two matching entries for buildpack ${previousBPName%_*}. Failing."
      exit 1
  fi


}
