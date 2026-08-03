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
        curl-minimal \
        gcc \
        glibc.i686 \
        make \
        cpio \
        kmod
  elif [ "$DRIVER_ARCH" = "ppc64le" ]; then
    dnf install -y \
        libglvnd-glx \
        ca-certificates \
        curl-minimal \
        gcc \
        glibc \
        make \
        cpio \
        kmod
  elif [ "$DRIVER_ARCH" = "aarch64" ]; then
    dnf install -y \
        libglvnd-glx \
        ca-certificates \
        curl-minimal \
        gcc \
        glibc \
        make \
        cpio \
        kmod
  fi

  # Download unzboot as kernel images are compressed in the zboot format on RHEL 9 arm64
  # unzboot is only available on the EPEL RPM repo
  rpm --import  https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  dnf config-manager --enable epel
  dnf install -y unzboot

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
  dnf install -y nvidia-fabricmanager-${DRIVER_VERSION} nvidia-fabric-manager-devel-${DRIVER_VERSION}
  dnf versionlock add nvidia-fabricmanager nvidia-fabric-manager-devel
}

nscq_install() {
  dnf install -y libnvidia-nscq-${DRIVER_VERSION}
  dnf versionlock add libnvidia-nscq
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    dnf install -y libnvsdm-${DRIVER_VERSION}
    dnf versionlock add libnvsdm
  fi
}

nvlink5_pkgs_install() {
  dnf install -y infiniband-diags nvlsm
}

imex_install() {
  dnf install -y nvidia-imex-${DRIVER_VERSION}
  dnf versionlock add nvidia-imex
}
extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      dnf module enable -y nvidia-driver:${DRIVER_BRANCH}-dkms
      dnf install -y 'dnf-command(versionlock)'

      # If running on a RockyLinux base image, we enable the Code Ready Builder RPM repo (crb)
      OS_RELEASE_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
      if [ "$OS_RELEASE_ID" = "rocky" ]; then
        dnf config-manager --set-enabled crb
      fi

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
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/${OS_ARCH}/cuda-rhel9.repo
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
