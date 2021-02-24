#!/bin/bash

# BUG: assumes you're running script from the top-level directory. (e.g. ci/localbuild.sh)

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

## Configuration

# DRIVER_VERSION='450.102.04'
DRIVER_VERSION='460.32.03'

REGISTRY='nvidia/driver'
# DOCKERHUB_RELEASE="yes"

CONTAMER_DIR="$HOME/nvidia/contamer"

NGC_REGISTRY='nvcr.io/nvidia/driver'
# NGC_RELEASE="yes"

## Values

# declare as an array
all_containers=()

## Functions

driver_container_build_simple()
{
  platform="$1"
  shift 1

  short_version="${DRIVER_VERSION}-${platform}"
  short_tag="${REGISTRY}:${short_version}"
  all_containers+=("${short_tag}")
  docker build -t "${short_tag}" \
      --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
      "${platform}"
}

driver_container_build_ubuntu()
{
  driver_container_build_simple "ubuntu18.04"
  driver_container_build_simple "ubuntu20.04"
  driver_container_build_simple "ubuntu16.04"

  driver_container_build_simple "centos7"
}

list_all_containers()
{
  echo "Results:"
  for container in "${all_containers[@]}"; do
    echo "${container}"
  done
}

scan_all_containers()
{
  for container in "${all_containers[@]}"; do
    echo "Scanning ... ${container}"
    tagname="${container##nvidia/driver:}"
    python3 contamer.py -ls --fail-on-non-os "${container}" 2>&1 | tee "scan-$(date +%Y%m%d)_${tagname}.txt"
  done
}

# pushes everything to dockerhub
dockerhub_push()
{
  for V in "${all_containers[@]}"; do
    docker push "${V}"
  done
}

# create aliases of all nvidia/driver:* to nvcr.io/nvidia/driver:*
ngc_alias()
{
  for V in "${all_containers[@]}"; do
    ngctag="${NGC_REGISTRY}:${V##nvidia/driver:}"
    docker tag "$V" "${ngctag}"
  done
}

# pushes everything to NGC
ngc_push()
{
  for V in "${all_containers[@]}"; do
    ngctag="${NGC_REGISTRY}:${V##nvidia/driver:}"
    docker push "${ngctag}"
  done
}

## Main

driver_container_build_ubuntu

list_all_containers

if [ -n "${CONTAMER_DIR}" -a -d "${CONTAMER_DIR}" ]; then
  pushd "${CONTAMER_DIR}"
  scan_all_containers
  popd
fi

if [ -n "${NGC_RELEASE}" ]; then
  ngc_alias

  docker login nvcr.io
  ngc_push
fi

if [ -n "${DOCKERHUB_RELEASE}" ]; then
  docker login
  dockerhub_push
fi

##END##
