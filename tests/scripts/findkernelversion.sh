#!/bin/bash

if [[ $# -ne 4 ]]; then
	echo " BASE_TARGET KERNEL_FLAVOR DRIVER_BRANCH DIST are required"
	exit 1
fi

export BASE_TARGET="${1}"
export KERNEL_FLAVOR="${2}"
export DRIVER_BRANCH="${3}"
export DIST="${4}"

export REGCTL_VERSION=v0.7.1
mkdir -p bin
curl -sSLo bin/regctl https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-amd64
chmod a+x bin/regctl
export PATH=$(pwd)/bin:${PATH}

# calculate kernel version of latest image
regctl image get-file ghcr.io/nvidia/driver:base-${BASE_TARGET}-${KERNEL_FLAVOR}-${DRIVER_BRANCH} /var/kernel_version.txt ./kernel_version.txt
export $(grep -oP 'KERNEL_VERSION=[^ ]+' ./kernel_version.txt)

# calculate driver tag
status=0
regctl tag ls  nvcr.io/nvidia/driver | grep "^${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}$" || status=$?
if [[ $status -eq 0 ]]; then
    export should_continue=false
else
    export should_continue=true
fi
# SHIVA
export should_continue=true
