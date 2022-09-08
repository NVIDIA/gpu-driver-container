#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

## Configuration

: "${DRIVER_VERSION:=510.85.03}"
: "${CUDA_VERSION:=11.7.0}"
#VERSION_ARRAY=(${DRIVER_VERSION//./ })
#DRIVER_BRANCH=${VERSION_ARRAY[0]}
IMAGE_NAME="$USER/vgpu-driver"

## quick and dirty build

platform="rhel8"
short_version="${DRIVER_VERSION}-${platform}"
short_tag="${IMAGE_NAME}:${short_version}"

docker build -t "${short_tag}" \
    --build-arg CUDA_VERSION="${CUDA_VERSION}" \
    --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
    "."

#--build-arg DRIVER_BRANCH="${DRIVER_BRANCH}" \

EXPORT_NAME="$(basename ${short_tag//:/_}).tar.gz"

echo "Exporting compressed image $EXPORT_NAME ..."
docker save "${short_tag}" | gzip > "$EXPORT_NAME"

ls -l "$EXPORT_NAME"

## Example deployment
# gunzip -c vgpu-driver_510.85.03-rhel8.tar.gz | docker load
# docker rm /driver ; docker run --privileged --name "driver" -v /etc/pki/entitlement:/etc/pki/entitlement -v /etc/yum.repos.d/redhat.repo:/etc/yum.repos.d/redhat.repo -v /etc/rhsm:/etc/rhsm $USER/vgpu-driver:510.85.03-rhel8

##END##
