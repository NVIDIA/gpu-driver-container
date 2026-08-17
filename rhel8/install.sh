#!/bin/bash
# Copyright (c) 2021-2023, NVIDIA CORPORATION. All rights reserved.

set -eu

DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && DRIVER_ARCH=${DRIVER_ARCH/arm64/aarch64}
echo "DRIVER_ARCH is $DRIVER_ARCH"

dep_installer () {
  if [ "$DRIVER_ARCH" = "x86_64" ]; then
    dnf install -y --nodocs \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc.i686 \
        make \
        cpio \
        kmod
  elif [ "$DRIVER_ARCH" = "ppc64le" ]; then
    dnf install -y --nodocs \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc \
        make \
        cpio \
        kmod
  elif [ "$DRIVER_ARCH" = "aarch64" ]; then
    dnf install -y --nodocs \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc \
        make \
        cpio \
        kmod
  fi

  dnf install -y --nodocs 'dnf-command(config-manager)'
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
  dnf install -y --nodocs nvidia-fabricmanager-${DRIVER_VERSION} nvidia-fabric-manager-devel-${DRIVER_VERSION}
  dnf versionlock add nvidia-fabricmanager nvidia-fabric-manager-devel
}

nscq_install() {
  dnf install -y --nodocs libnvidia-nscq-${DRIVER_VERSION}
  dnf versionlock add libnvidia-nscq
}

nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    dnf install -y --nodocs libnvsdm-${DRIVER_VERSION}
    dnf versionlock add libnvsdm
  fi
}

nvlink5_pkgs_install() {
  dnf install -y --nodocs infiniband-diags nvlsm
}

imex_install() {
  dnf install -y --nodocs nvidia-imex-${DRIVER_VERSION}
  dnf versionlock add nvidia-imex
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      dnf module enable -y nvidia-driver:${DRIVER_BRANCH}-dkms
      dnf install -y --nodocs 'dnf-command(versionlock)'

      fabricmanager_install
      nscq_install
      nvsdm_install
      nvlink5_pkgs_install
      imex_install
      rm -rf /usr/share/doc/*
      dnf clean all
  fi
}

setup_cuda_repo() {
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa};
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/${OS_ARCH}/cuda-rhel8.repo
}

if [ "$1" = "nvinstall" ]; then
  nvidia_installer
elif [ "$1" = "depinstall" ]; then
  dep_installer
elif [ "$1" = "extrapkgsinstall" ]; then
  extra_pkgs_install
elif [ "$1" = "setup_cuda_repo" ]; then
  setup_cuda_repo
else
  echo "Unknown function: $1"
fi
