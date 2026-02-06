#!/bin/bash
# Copyright (c) 2021-2023, NVIDIA CORPORATION. All rights reserved.

set -eu

DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && DRIVER_ARCH=${DRIVER_ARCH/arm64/aarch64}
echo "DRIVER_ARCH is $DRIVER_ARCH"

dep_installer () {
  if [ "$DRIVER_ARCH" = "x86_64" ]; then
    dnf install -y \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc.i686 \
        make \
        cpio \
        kmod
  elif [ "$DRIVER_ARCH" = "ppc64le" ]; then
    dnf install -y \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc \
        make \
        cpio \
        kmod
  elif [ "$DRIVER_ARCH" = "aarch64" ]; then
    dnf install -y \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc \
        make \
        cpio \
        kmod
  fi
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
  elif [ "$DRIVER_ARCH" = "ppc64le" ]; then
    ./nvidia-installer --silent \
                       --no-kernel-module \
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
  elif [ "$DRIVER_ARCH" = "aarch64" ]; then
    ./nvidia-installer --silent \
                       --no-kernel-module \
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
  fi
}

fabricmanager_install() {
  local fabricmanager_package_name
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    fabricmanager_package_name=nvidia-fabricmanager
  else
    fabricmanager_package_name=nvidia-fabric-manager
  fi
  dnf install -y ${fabricmanager_package_name}-${DRIVER_VERSION}
  dnf versionlock add ${fabricmanager_package_name}
}

nscq_install() {
  local nscq_package_name
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    nscq_package_name=libnvidia-nscq
  else
    nscq_package_name=libnvidia-nscq-${DRIVER_BRANCH}
  fi
  dnf install -y ${nscq_package_name}-${DRIVER_VERSION}
  dnf versionlock add ${nscq_package_name}
}

nvsdm_install() {
  local nvsdm_package_name
  if [ "$TARGETARCH" = "amd64" ]; then
    if [ "$DRIVER_BRANCH" -ge "580" ]; then
      nvsdm_package_name=libnvsdm
    elif [ "$DRIVER_BRANCH" -ge "570" ]; then
      nvsdm_package_name=libnvsdm-${DRIVER_BRANCH}
    else
      return 0
    fi
    dnf install -y ${nvsdm_package_name}-${DRIVER_VERSION}
    dnf versionlock add ${nvsdm_package_name}
  fi
}

nvlink5_pkgs_install() {
  if [ "$DRIVER_BRANCH" -ge "550" ]; then
    dnf install -y infiniband-diags nvlsm
  fi
}

imex_install() {
  local imex_package_name
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    imex_package_name=nvidia-imex
  elif [ "$DRIVER_BRANCH" -ge "550" ]; then
    imex_package_name=nvidia-imex-${DRIVER_BRANCH}
  else
    return 0
  fi
  dnf install -y ${imex_package_name}-${DRIVER_VERSION}
  dnf versionlock add ${imex_package_name}
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      dnf module enable -y nvidia-driver:${DRIVER_BRANCH}-dkms
      dnf install -y 'dnf-command(versionlock)'

      fabricmanager_install
      nscq_install
      nvsdm_install
      nvlink5_pkgs_install
      imex_install
  fi
}

if [ "$1" = "nvinstall" ]; then
  nvidia_installer
elif [ "$1" = "depinstall" ]; then
  dep_installer
elif [ "$1" = "extrapkgsinstall" ]; then
  extra_pkgs_install
else
  echo "Unknown function: $1"
fi
