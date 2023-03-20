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

    trap "docker rm -f base-${BASE_TARGET}" EXIT
    docker run -d --name base-${BASE_TARGET} -e DRIVER_BRANCH=${DRIVER_BRANCH} --entrypoint /usr/local/bin/generate-ci-config ghcr.io/arangogutierrez/driver:base-jammy "${BASE_TARGET}"
    # try 3 times every 3 seconds to get the file, if success exit the loop
    for i in {1..10}; do
        docker cp base-${BASE_TARGET}:/var/kernel_version.txt kernel_version.txt && break
        sleep 10
    done

    source kernel_version.txt
}

function buildImage(){
    # Build the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} build-${DIST}-${DRIVER_VERSION}
}

function pushImage(){
    # push the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} IMAGE_NAME=${IN_REGISTRY}/${IN_IMAGE_NAME} VERSION=${IN_VERSION} OUT_VERSION=${IN_VERSION} push-${DIST}
}

function pullImage(){
    # pull the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} pull-${DIST}-${DRIVER_VERSION}
}

function archiveImage(){
    # archive the image
    make DRIVER_VERSIONS=${DRIVER_VERSIONS} archive-${DIST}-${DRIVER_VERSION}
}   

sourceVersions
case $1 in
    build)
        buildImage
        ;;
    push)
        pushImage
        ;;
    pull)
        pullImage
        ;;
    archive)
        archiveImage
        ;;
    *)
        echo "Usage: $0 {build|push|pull|archive}"
        exit 1
esac
