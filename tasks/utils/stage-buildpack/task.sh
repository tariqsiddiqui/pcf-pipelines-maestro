#!/bin/bash -eu

# Copyright 2017-Present Pivotal Software, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

tar -xf cf-cli/*.tgz cf
chmod +x cf

./cf api $CF_API_URI --skip-ssl-validation
./cf auth $CF_USERNAME $CF_PASSWORD
./cf buildpacks

set +e
existing_buildpack=$(./cf buildpacks | grep "${BUILDPACK_NAME}\s" | sed -E "s/[[:space:]]+/ /g")
set -e
if [ -z "${existing_buildpack}" ]; then
  COUNT=$(./cf buildpacks | grep --regexp=".zip" --count)
  declare -i NEW_POSITION=$(expr $COUNT + 1)
  echo "Creating Buildpack $BUILDPACK_NAME"
  ./cf create-buildpack $BUILDPACK_NAME buildpack/*.zip $NEW_POSITION --enable
else
  index=$(echo $existing_buildpack | cut -d' ' -f2)
  bp_zip_file=$(echo $existing_buildpack | cut -d " " -f 5)
  if [[ -e "./buildpack/$bp_zip_file" ]]; then
    echo "Buildpack already matches with existing. Exiting"
  else
    echo "Updating Buildpack to $BUILDPACK_NAME"
    ./cf update-buildpack $BUILDPACK_NAME -p buildpack/*.zip -i $index --enable
  fi
fi

./cf buildpacks
