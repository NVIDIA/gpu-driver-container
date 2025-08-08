# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#!/bin/bash

set -eu

dep_installer () {
  if [ "$DRIVER_ARCH" = "x86_64" ]; then
    yum install -y \
        ca-certificates \
        curl \
        gcc \
        glibc.i686 \
        make \
        kmod
  else
      echo "DRIVER_ARCH doesn't match a known arch target"
	  exit 1
  fi
  rm -rf /var/cache/yum/*
}

nvswitch_dep_installer() {
    version_array=(${DRIVER_VERSION//./ })
    DRIVER_BRANCH=${version_array[0]}
    if [ ${version_array[0]} -ge 470 ] || ([ ${version_array[0]} == 460 ] && [ ${version_array[1]} -ge 91 ]); then
      fm_pkg=nvidia-fabric-manager-${DRIVER_VERSION}-1
    else \
      fm_pkg=nvidia-fabricmanager-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
    fi; \
    nscq_pkg=libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
    yum install -y \
        ${fm_pkg} \
        ${nscq_pkg}
    rm -rf /var/cache/yum/*
}

nvidia_installer () {
  if [ "$DRIVER_ARCH" = "x86_64" ]; then
    ./nvidia-installer --silent \
                       --no-kernel-module \
                       --install-compat32-libs \
                       --no-nouveau-check \
                       --no-nvidia-modprobe \
                       --no-rpms \
                       --no-backup \
                       --no-check-for-alternate-installs \
                       --no-libglx-indirect \
                       --no-install-libglvnd \
                       --x-prefix=/tmp/null \
                       --x-module-path=/tmp/null \
                       --x-library-path=/tmp/null \
                       --x-sysconfig-path=/tmp/null
  else
    echo "DRIVER_ARCH doesn't match a known arch target"
    exit 1
  fi
}

if [ "$1" = "nvinstall" ]; then
  nvidia_installer
elif [ "$1" = "depinstall" ]; then
	dep_installer
elif [ "$1" = "nvswitch_depinstall" ]; then
	nvswitch_dep_installer
else
  echo "Unknown function: $1"
fi
