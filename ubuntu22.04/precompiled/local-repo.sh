#!/usr/bin/env bash

set -eu

LOCAL_REPO_DIR=/usr/local/repos

download_apt_with_dep () {
  apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $1 | grep "^\w" | sort -u)
}

download_driver_package_deps () {
  pushd ${LOCAL_REPO_DIR}
  download_apt_with_dep linux-objects-nvidia-${DRIVER_BRANCH}-server-${KERNEL_VERSION}
  download_apt_with_dep linux-signatures-nvidia-${KERNEL_VERSION}
  download_apt_with_dep linux-modules-nvidia-${DRIVER_BRANCH}-server-${KERNEL_VERSION}
  download_apt_with_dep linux-modules-nvidia-${DRIVER_BRANCH}-server-open-${KERNEL_VERSION}
  download_apt_with_dep nvidia-utils-${DRIVER_BRANCH}-server
  download_apt_with_dep nvidia-compute-utils-${DRIVER_BRANCH}-server
  download_apt_with_dep libnvidia-cfg1-${DRIVER_BRANCH}-server
  download_apt_with_dep nvidia-fabricmanager-${DRIVER_BRANCH}
  download_apt_with_dep libnvidia-nscq-${DRIVER_BRANCH}
  popd
}

build_local_apt_repo () {
  dpkg-scanpackages ${LOCAL_REPO_DIR} /dev/null | gzip -9c | tee Packages.gz > /dev/null
  echo "deb [trusted=yes] file:${LOCAL_REPO_DIR} ./" > /etc/apt/sources.list
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
