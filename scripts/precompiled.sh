#!/bin/bash
# precompiled.sh holds extra steps needed for handling precompiled images
# during GitLab pipelines
set -x

# Get the KERNEL_VERSION DRIVER_VERSION and DRIVER_VERSIONS from base image
function sourceVersions(){

    # if kernel_version.txt exists source it and exit function
    if [ -f kernel_version.txt ]; then
        source kernel_version.txt
        return 0
    fi
    # if KERNEL_VERSION DRIVER_VERSION and DRIVER_VERSIONS are set exit the function
    if [ -n "$KERNEL_VERSION" ] && [ -n "$DRIVER_VERSION" ] && [ -n "$DRIVER_VERSIONS" ]; then
        return 0
    fi
    # check if BASE_TARGET is set
    if [ -z "$BASE_TARGET" ]; then
        echo "BASE_TARGET is not set"
        exit 1
    fi

    if command -v regctl; then
        regctl image get-file ghcr.io/nvidia/driver:base-${BASE_TARGET}-${LTS_KERNEL}-${KERNEL_FLAVOR}-${DRIVER_BRANCH} /var/kernel_version.txt kernel_version.txt
    else
        trap "docker rm -f base-${BASE_TARGET}" EXIT
        docker run --pull=always -d --name base-${BASE_TARGET}-${KERNEL_FLAVOR} ghcr.io/nvidia/driver:base-${BASE_TARGET}-${LTS_KERNEL}-${KERNEL_FLAVOR}-${DRIVER_BRANCH}
        # try 3 times every 3 seconds to get the file, if success exit the loop
        for i in {1..3}; do
            docker cp base-${BASE_TARGET}-${KERNEL_FLAVOR}:/var/kernel_version.txt kernel_version.txt && break
            sleep 10
        done
    fi

    source kernel_version.txt
}

function buildBaseImage(){
    # Build the base image
    make DRIVER_BRANCH=${DRIVER_BRANCH} KERNEL_FLAVOR=${KERNEL_FLAVOR} build-base-${BASE_TARGET}
}

function buildImage(){
    # Build the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} DRIVER_BRANCH=${DRIVER_BRANCH} build-${DIST}-${DRIVER_VERSION}
}

function pushBaseImage(){
    # push the base image
    if [ -z "$IMAGE_NAME" ]; then
        IMAGE_NAME="${STAGING_REGISTRY}"/driver
    fi
    make IMAGE_NAME=${IMAGE_NAME} DRIVER_BRANCH=${DRIVER_BRANCH} KERNEL_FLAVOR=${KERNEL_FLAVOR} push-base-${BASE_TARGET}
}

function pushImage(){
	# check if image exists in output registry
	# note: DIST is in the form "signed_<distribution>", so we drop the '*_' prefix
	# to extract the distribution string.
	local out_image=${OUT_IMAGE_NAME}:${DRIVER_BRANCH}-${KERNEL_VERSION}-${DIST##*_}
	if imageExists "$out_image"; then
		echo "image tag already exists in output registry - $out_image"
		if [ "$FORCE_PUSH" != "true" ]; then
			echo "exiting"
			return 0
		fi
		echo "overwriting image tag - $out_image"
	fi
    # push the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} DRIVER_BRANCH=${DRIVER_BRANCH} push-${DIST}
}

function pullImage(){
    # pull the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} DRIVER_BRANCH=${DRIVER_BRANCH} pull-${DIST}-${DRIVER_VERSION}
}

function archiveImage(){
    # archive the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} DRIVER_BRANCH=${DRIVER_BRANCH} archive-${DIST}-${DRIVER_VERSION}
}

function imageExists(){
	regctl manifest get $1 --list > /dev/null && return 0 || return 1
}

case $1 in
    build)
        buildBaseImage
        pushBaseImage
        sourceVersions
        buildImage
        ;;
    push)
        sourceVersions
        pushImage
        ;;
    pull)
        sourceVersions
        pullImage
        ;;
    archive)
        sourceVersions
        archiveImage
        ;;
    version)
        sourceVersions
        ;;    
    *)
        echo "Usage: $0 {build|push|pull|archive|version}"
        exit 1
esac
