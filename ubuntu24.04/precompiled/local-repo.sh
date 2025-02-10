#!/usr/bin/env bash

set -eu

LOCAL_REPO_DIR=/usr/local/repos

download_apt_with_dep () {
  local package="$1"
  apt-get download $package
  apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $package | grep "^\w" | sort -u)
}

download_driver_package_deps () {
  apt-get update
  pushd ${LOCAL_REPO_DIR}

  download_apt_with_dep linux-objects-nvidia-${DRIVER_BRANCH}-server-${KERNEL_VERSION}
  download_apt_with_dep linux-signatures-nvidia-${KERNEL_VERSION}
  download_apt_with_dep linux-modules-nvidia-${DRIVER_BRANCH}-server-${KERNEL_VERSION}
  download_apt_with_dep linux-modules-nvidia-${DRIVER_BRANCH}-server-open-${KERNEL_VERSION}
  download_apt_with_dep nvidia-utils-${DRIVER_BRANCH}-server
  download_apt_with_dep nvidia-headless-no-dkms-${DRIVER_BRANCH}-server
  download_apt_with_dep libnvidia-decode-${DRIVER_BRANCH}-server
  download_apt_with_dep libnvidia-extra-${DRIVER_BRANCH}-server
  download_apt_with_dep libnvidia-encode-${DRIVER_BRANCH}-server
  download_apt_with_dep libnvidia-fbc1-${DRIVER_BRANCH}-server

  apt-get download nvidia-fabricmanager-${DRIVER_BRANCH}=${DRIVER_VERSION}-1
  apt-get download libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1

  ls -al .
  popd
}

build_local_apt_repo () {
  pushd ${LOCAL_REPO_DIR}
  dpkg-scanpackages . /dev/null | gzip -9c | tee Packages.gz > /dev/null
  echo "deb [trusted=yes] file:${LOCAL_REPO_DIR} ./" > /etc/apt/sources.list
  popd
  apt-get update
}

if [ "$1" = "download_driver_package_deps" ]; then
  download_driver_package_deps
elif [ "$1" = "build_local_apt_repo" ]; then
  build_local_apt_repo
else
  echo "Unknown function: $1"
  exit 1
fi
