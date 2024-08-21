#!/bin/bash

if [[ "${SKIP_INSTALL}" == "true" ]]; then
    echo "Skipping install: SKIP_INSTALL=${SKIP_INSTALL}"
    exit 0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

export REGCTL_VERSION=v0.4.7
mkdir -p bin
curl -sSLo bin/regctl https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-amd64
chmod a+x bin/regctl
export PATH=$(pwd)/bin:${PATH}
DRIVER_BRANCH=$(echo "${TARGET_DRIVER_VERSION}" | cut -d '.' -f 1)
regctl image get-file ghcr.io/nvidia/driver:base-${BASE_TARGET}-${KERNEL_FLAVOR}-${DRIVER_BRANCH} /var/kernel_version.txt ${SCRIPT_DIR}/kernel_version.txt || true
