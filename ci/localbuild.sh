#!/bin/bash

# BUG: assumes you're running script from the top-level directory. (e.g. ci/localbuild.sh)

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

## Configuration

: "${DRIVER_VERSION:=460.73.01}"
VERSION_ARRAY=(${DRIVER_VERSION//./ })
DRIVER_BRANCH=${VERSION_ARRAY[0]}

REGISTRY='nvidia/driver'
: "${DOCKERHUB_RELEASE:=""}"

PULSE_DIR="$HOME/git/pulse-scanner"
: "${NSPECT_ID:=""}"
: "${SSA_CLIENT_SECRET:=""}"

NGC_STAGING_REGISTRY='nvcr.io/nvstaging/cloud-native/driver'
: "${NGC_STAGING_RELEASE:=""}"

NGC_PROD_REGISTRY='nvcr.io/nvidia/driver'
: "${NGC_PROD_RELEASE:=""}"

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
      --build-arg DRIVER_BRANCH="${DRIVER_BRANCH}" \
      "${platform}"
}

driver_container_build_ubuntu()
{
  driver_container_build_simple "ubuntu18.04"
  driver_container_build_simple "ubuntu20.04"
  driver_container_build_simple "ubuntu16.04"
}

driver_container_build_centos()
{
  driver_container_build_simple "centos7"
  driver_container_build_simple "centos8"
}

driver_container_build_rhel()
{
  driver_container_build_simple "rhel7"
  driver_container_build_simple "rhel8"
  driver_container_build_simple "rhel9"
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
  allow_failure="-a"
  if [ "${NGC_PROD_RELEASE}" = "yes" ]; then
    allow_failure=""
  fi
  for container in "${all_containers[@]}"; do
    echo "Scanning ... ${container}"
    tagname="${container##nvidia/driver:}"
    ./local_scan.sh "${allow_failure}" -i $container -n $NSPECT_ID -s $SSA_CLIENT_SECRET 2>&1 | tee "scan-$(date +%Y%m%d)_${tagname}.txt"
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
    ngctag="${1}:${V##nvidia/driver:}"
    docker tag "$V" "${ngctag}"
  done
}

# pushes everything to NGC
ngc_push()
{
  for V in "${all_containers[@]}"; do
    ngctag="${1}:${V##nvidia/driver:}"
    docker push "${ngctag}"
  done
}

## Main

driver_container_build_ubuntu
driver_container_build_rhel
driver_container_build_centos

list_all_containers

if [ -n "${PULSE_DIR}" -a -d "${PULSE_DIR}" ]; then
  if [ -n "${NSPECT_ID}" -a -n "${SSA_CLIENT_SECRET}" ]; then
    pushd "${PULSE_DIR}"
    scan_all_containers
    popd
  else
    echo "Skipping scans, NSPECT_ID and SSA_CLIENT_SECRET not set"
  fi
fi

if [ -n "${NGC_STAGING_RELEASE}" ]; then
  ngc_alias "${NGC_STAGING_REGISTRY}"
  docker login nvcr.io
  ngc_push "${NGC_STAGING_REGISTRY}"
fi

if [ "${NGC_PROD_RELEASE}" = "yes" ]; then
  ngc_alias "${NGC_PROD_REGISTRY}"
  docker login nvcr.io
  ngc_push "${NGC_PROD_REGISTRY}"
fi

if [ "${DOCKERHUB_RELEASE}" = "yes" ]; then
  docker login
  dockerhub_push
fi

##END##
