# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#!/usr/bin/env bash

set -eu

download_installer () {
    DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && DRIVER_ARCH=${DRIVER_ARCH/arm64/aarch64} && curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run && \
    chmod +x  NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run;
}

dep_install () {
    if [ "$TARGETARCH" = "amd64" ]; then
        dpkg --add-architecture i386 && \
            apt-get update && apt-get install -y --no-install-recommends \
            apt-utils \
            build-essential \
            ca-certificates \
            curl \
            kmod \
            file \
            libelf-dev \
            libglvnd-dev \
            pkg-config && \
        rm -rf /var/lib/apt/lists/*
    elif [ "$TARGETARCH" = "arm64" ]; then
        dpkg --add-architecture arm64 && \
            apt-get update && apt-get install -y \
            build-essential \
            ca-certificates \
            curl \
            kmod \
            file \
            libelf-dev \
            libglvnd-dev && \
        rm -rf /var/lib/apt/lists/*
    fi
}

repo_setup () {
    if [ "$TARGETARCH" = "amd64" ]; then
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main universe" > /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main universe" >> /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main universe" >> /etc/apt/sources.list && \
        usermod -o -u 0 -g 0 _apt
    elif [ "$TARGETARCH" = "arm64" ]; then
        echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy main universe" > /etc/apt/sources.list && \
        echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy-updates main universe" >> /etc/apt/sources.list && \
        echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports jammy-security main universe" >> /etc/apt/sources.list && \
        usermod -o -u 0 -g 0 _apt
    else
        echo "TARGETARCH doesn't match a known arch target"
        exit 1
    fi
}

fabricmanager_install() {
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    apt-get install -y --no-install-recommends nvidia-fabricmanager=${DRIVER_VERSION}-1
  else
    apt-get install -y --no-install-recommends nvidia-fabricmanager-${DRIVER_BRANCH}=${DRIVER_VERSION}-1
  fi
}

nscq_install() {
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    apt-get install -y --no-install-recommends libnvidia-nscq=${DRIVER_VERSION}-1
  else
    apt-get install -y --no-install-recommends libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1
  fi
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    if [ "$DRIVER_BRANCH" -ge "580" ]; then
       apt-get install -y --no-install-recommends libnvsdm=${DRIVER_VERSION}-1
    elif [ "$DRIVER_BRANCH" -ge "570" ]; then
       apt-get install -y --no-install-recommends libnvsdm-${DRIVER_BRANCH}=${DRIVER_VERSION}-1
    fi
  fi
}

nvlink5_pkgs_install() {
  if [ "$DRIVER_BRANCH" -ge "550" ]; then
    apt-get install -y --no-install-recommends nvlsm infiniband-diags
  fi
}

imex_install() {
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    apt-get install -y --no-install-recommends nvidia-imex=${DRIVER_VERSION}-1
  elif [ "$DRIVER_BRANCH" -ge "550" ]; then
    apt-get install -y --no-install-recommends nvidia-imex-${DRIVER_BRANCH}=${DRIVER_VERSION}-1;
  fi
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      apt-get update

      fabricmanager_install
      nscq_install
      nvsdm_install
      nvlink5_pkgs_install
      imex_install

      rm -rf /var/lib/apt/lists/*
  fi
}

if [ "$1" = "reposetup" ]; then
  repo_setup
elif [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "extra_pkgs_install" ]; then
  extra_pkgs_install
elif [ "$1" = "download_installer" ]; then
  download_installer
else
  echo "Unknown function: $1"
  exit 1
fi

