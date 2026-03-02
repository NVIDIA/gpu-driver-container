#!/bin/bash

if [[ $# -lt 4 || $# -gt 5 ]]; then
	echo " KERNEL_FLAVOR DRIVER_BRANCH DIST LTS_KERNEL or KERNEL_FLAVOR DRIVER_BRANCH DIST LTS_KERNEL PLATFORM_SUFFIX are required"
	exit 1
fi

export KERNEL_FLAVOR="${1}"
export DRIVER_BRANCH="${2}"
export DIST="${3}"
export LTS_KERNEL="${4}"
export PLATFORM_SUFFIX="${5}"

export REGCTL_VERSION=v0.7.1
mkdir -p bin
curl -sSLo bin/regctl https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-amd64
chmod a+x bin/regctl
export PATH=$(pwd)/bin:${PATH}

# calculate kernel version of latest image
prefix="kernel-version-${DRIVER_BRANCH}-${LTS_KERNEL}"
suffix="${KERNEL_FLAVOR}-${DIST}"

artifact_dir="./kernel-version-artifacts"
artifact_file=$(find "$artifact_dir" -maxdepth 1 -type f -name "${prefix}*-${suffix}.tar" | head -1)
if [ -n "$artifact_file" ]; then
    tar -xf "$artifact_file" -C ./
    export $(grep -oE 'KERNEL_VERSION=[^ ]+' ./kernel_version.txt)
    rm -f kernel_version.txt
fi

# calculate driver tag
status_nvcr=0
status_ghcr=0
PLATFORM=$(echo "${PLATFORM_SUFFIX}" | sed 's/-//')
[ -z "$PLATFORM" ] && PLATFORM=amd64
regctl manifest inspect nvcr.io/nvidia/driver:${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST} --platform=linux/${PLATFORM} > /dev/null 2>&1; status_nvcr=$?
regctl manifest inspect ghcr.io/nvidia/driver:${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST} --platform=linux/${PLATFORM} > /dev/null 2>&1; status_ghcr=$?

if [[ $status_nvcr -eq 0 || $status_ghcr -eq 0 ]]; then
    export should_continue=false
else
    export should_continue=true
fi
