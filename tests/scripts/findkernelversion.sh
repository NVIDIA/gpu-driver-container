#!/bin/bash

if [[ $# -ne 5 ]]; then
	echo " BASE_TARGET KERNEL_FLAVOR DRIVER_BRANCH DIST LTS_KERNEL are required"
	exit 1
fi

export BASE_TARGET="${1}"
export KERNEL_FLAVOR="${2}"
export DRIVER_BRANCH="${3}"
export DIST="${4}"
export LTS_KERNEL="${5}"

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
status=0
regctl tag ls  nvcr.io/nvidia/driver | grep "^${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}$" || status=$?
if [[ $status -eq 0 ]]; then
    export should_continue=false
else
    export should_continue=true
fi
export should_continue=true
