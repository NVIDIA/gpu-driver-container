#!/bin/bash

if [[ $# -lt 4 ]]; then
	echo " KERNEL_FLAVOR DRIVER_BRANCH DIST LTS_KERNEL [FORCE_REBUILD] are required"
	exit 1
fi

export KERNEL_FLAVOR="${1}"
export DRIVER_BRANCH="${2}"
export DIST="${3}"
export LTS_KERNEL="${4}"
FORCE_REBUILD="${5:-false}"

export REGCTL_VERSION=v0.7.1
mkdir -p bin
curl -sSLo bin/regctl https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-amd64
chmod a+x bin/regctl
export PATH=$(pwd)/bin:${PATH}

# calculate kernel version of latest image
prefix="kernel-version-${DRIVER_BRANCH}-${LTS_KERNEL}"
suffix="${kernel_flavor}-${DIST}"

artifact_dir="./kernel-version-artifacts"
artifact=$(find "$artifact_dir" -maxdepth 1 -type d -name "${prefix}*-${suffix}" | head -1)
if [ -n "$artifact" ]; then
    artifact_name=$(basename "$artifact")
    if [ -f "$artifact/${artifact_name}.tar" ]; then
        tar -xf "$artifact/${artifact_name}.tar" -C ./
        export $(grep -oP 'KERNEL_VERSION=[^ ]+' ./kernel_version.txt)
        rm -f kernel_version.txt
    fi
fi

# calculate driver tag
nvcr_tags=$(regctl tag ls nvcr.io/nvidia/driver 2>&1)
nvcr_status=$?
if [[ $nvcr_status -ne 0 ]]; then
    echo "failed to list tags from nvcr.io/nvidia/driver (exit $nvcr_status): $nvcr_tags" >&2
    export should_continue=false
    export regctl_error=true
    return 1
fi

if echo "$nvcr_tags" | grep -q "^${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}$"; then
    echo "image tag ${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST} already exists on nvcr.io - rebuild not allowed" >&2
    export should_continue=false
elif [[ "$FORCE_REBUILD" == "true" ]]; then
    echo "force rebuild requested for ${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}" >&2
    export should_continue=true
else
    ghcr_tags=$(regctl tag ls ghcr.io/nvidia/driver 2>&1)
    ghcr_status=$?
    if [[ $ghcr_status -ne 0 ]]; then
        echo "failed to list tags from ghcr.io/nvidia/driver (exit $ghcr_status): $ghcr_tags" >&2
        export should_continue=false
        export regctl_error=true
        return 1
    fi
    if echo "$ghcr_tags" | grep -q "^${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST}$"; then
        export should_continue=false
    else
        export should_continue=true
    fi
fi
