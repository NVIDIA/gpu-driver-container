#!/bin/bash

if [[ $# -ne 4 ]]; then
	echo " KERNEL_FLAVOR DRIVER_BRANCH DIST LTS_KERNEL are required"
	exit 1
fi

export KERNEL_FLAVOR="${1}"
export DRIVER_BRANCH="${2}"
export DIST="${3}"
export LTS_KERNEL="${4}"

export REGCTL_VERSION=v0.7.1
mkdir -p bin
curl -sSLo bin/regctl https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-amd64
chmod a+x bin/regctl
export PATH=$(pwd)/bin:${PATH}

# calculate kernel version of latest image
prefix="kernel-version-${DRIVER_BRANCH}-${LTS_KERNEL}"
suffix="${kernel_flavor}-${DIST}"
artifacts=$(gh api -X GET /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts --paginate --jq '.artifacts[].name')
# find the matching artifact dynamically
for artifact in $artifacts; do
    if [[ $artifact == $prefix*-$suffix ]]; then
        gh run download --name "$artifact" --dir ./
        tar -xf $artifact.tar 
        rm -f $artifact.tar
        export $(grep -oP 'KERNEL_VERSION=[^ ]+' ./kernel_version.txt)
        rm -f kernel_version.txt
        break
    fi
done

# calculate driver tag
status_nvcr=0
status_ghcr=0
regctl tag ls  nvcr.io/nvidia/driver | grep "^${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}$" || status_nvcr=$?
regctl tag ls  ghcr.io/nvidia/driver | grep "^${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}$" || status_ghcr=$?
if [[ $status_nvcr -eq 0 || $status_ghcr -eq 0 ]]; then
    export should_continue=false
else
    export should_continue=true
fi
