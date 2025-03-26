#!/usr/bin/env bash

set -eu

LOCAL_REPO_DIR=/usr/local/repos
DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && DRIVER_ARCH=${DRIVER_ARCH/arm64/aarch64}
DRIVER_RUN_FILE=NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION

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

fetch_nvidia_installer () {
  curl -fSsl -O $BASE_URL/$DRIVER_VERSION/$DRIVER_RUN_FILE.run
  chmod +x $DRIVER_RUN_FILE.run
  sh $DRIVER_RUN_FILE.run -x
  mv $DRIVER_RUN_FILE/nvidia-installer /usr/bin/
  rm -rf $DRIVER_RUN_FILE
  rm $DRIVER_RUN_FILE.run
}

if [ "$1" = "download_driver_package_deps" ]; then
  download_driver_package_deps
elif [ "$1" = "build_local_apt_repo" ]; then
  build_local_apt_repo
elif [ "$1" = "fetch_nvidia_installer" ]; then
  fetch_nvidia_installer
else
  echo "Unknown function: $1"
  exit 1
fi
