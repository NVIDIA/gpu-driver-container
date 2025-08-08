# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#!/bin/bash
#
# Gets all tags from a gitlab container registry, saving them to a file.
#
## These variables be in the environment when calling this script:
# DRIVER_VERSION and/or ALL_DRIVER_VERSIONS
# API_TOKEN
# CI_API_V4_URL
# CI_PROJECT_PATH
# CI_PROJECT_ID
#
# Optionally:
# TAGS_REGEX
#
# Output files:
# ./driver-tags

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Utility functions & logging

die() {
  echo -e "$0 \\033[0;41;30m[🛑] $*\\033[0m" >&2
}

warn() {
  echo -e "\\033[0;43;30m[⚠️] $*\\033[0m" >&2
}

log() {
  echo -e "\\033[1;32m[+] $*\\033[0m" >&2
}

# Settings & Configuration

TAGS_OUTFILE=driver-tags

# Sanity checks

if [ -z "$ALL_DRIVER_VERSIONS" ] && [ -z "$DRIVER_VERSION" ]; then
  die "Driver Version must be specified with environment variable DRIVER_VERSION or ALL_DRIVER_VERSIONS"
elif [ -z "$ALL_DRIVER_VERSIONS" ]; then
  # if empty, then use DRIVER_VERSION
  ALL_DRIVER_VERSIONS="$DRIVER_VERSION"
fi

if [ -z "$API_TOKEN" ]; then
  die "A valid Gitlab API token must be specified with environment variable API_TOKEN"
fi

# Main

# tags pulled with $CI_PROJECT_NAME to work-around issue with contamer's support for local scans.
HEADER="PRIVATE-TOKEN: ${API_TOKEN}"
IMAGES_URL="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/registry/repositories"
echo "Repositories URL: ${IMAGES_URL}"
IMAGE_ID=$(curl -fsSL --header "${HEADER}" "${IMAGES_URL}" | jq -r --arg CI_PROJECT_PATH "$CI_PROJECT_PATH" '.[] | select(.path == $CI_PROJECT_PATH) | .id')

# bail if the registry is new and empty
if [ -z "$IMAGE_ID" ]; then
  warn "No images available in repository at ${CI_PROJECT_PATH} ... skipping"
  exit 0
fi

touch "${TAGS_OUTFILE}"

TAGS_URL="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/registry/repositories/${IMAGE_ID}/tags"
for driver_ver in ${ALL_DRIVER_VERSIONS};
do
  TAGS_REGEX="${TAGS_REGEX:-"$driver_ver"}"
  echo "Tags URL: ${TAGS_URL}"
  curl -fsSL --header "${HEADER}" "${TAGS_URL}" | jq -r --arg TAGS_REGEX "$TAGS_REGEX" '.[] | select(.name|test($TAGS_REGEX)) | .location' >> "${TAGS_OUTFILE}"
done
