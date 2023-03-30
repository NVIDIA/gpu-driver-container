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
        regctl image get-file registry.gitlab.com/nvidia/container-images/driver/staging/driver:base-${BASE_TARGET}-${DRIVER_BRANCH} /var/kernel_version.txt kernel_version.txt
    else
        trap "docker rm -f base-${BASE_TARGET}" EXIT
        docker run -d --name base-${BASE_TARGET} registry.gitlab.com/nvidia/container-images/driver/staging/driver:base-${BASE_TARGET}-${DRIVER_BRANCH} 
        # try 3 times every 3 seconds to get the file, if success exit the loop
        for i in {1..3}; do
            docker cp base-${BASE_TARGET}:/var/kernel_version.txt kernel_version.txt && break
            sleep 10
        done
    fi

    source kernel_version.txt
}

function buildBaseImage(){
    # Build the base image
    make DRIVER_BRANCH=${DRIVER_BRANCH} build-base-${BASE_TARGET}
}

function buildImage(){
    # Build the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS}  build-${DIST}-${DRIVER_VERSION}
}

function pushBaseImage(){
    # push the base image
    if [ -z "$IMAGE_NAME" ]; then
        IMAGE_NAME="${STAGING_REGISTRY}"/driver
    fi
    make IMAGE_NAME=${IMAGE_NAME} DRIVER_BRANCH=${DRIVER_BRANCH} push-base-${BASE_TARGET}
}

function pushImage(){
    # push the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} push-${DIST}
}

function pullImage(){
    # pull the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} pull-${DIST}-${DRIVER_VERSION}
}

function archiveImage(){
    # archive the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} archive-${DIST}-${DRIVER_VERSION}
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
    *)
        echo "Usage: $0 {build|push|pull|archive}"
        exit 1
esac
