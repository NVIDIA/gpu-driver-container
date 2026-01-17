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
  if [ "$DRIVER_BRANCH" -ge "590" ]; then
    dnf install -y nvidia-fabricmanager-${DRIVER_VERSION}-1.el9
  elif [ "$DRIVER_BRANCH" -ge "580" ]; then
    dnf install -y nvidia-fabricmanager-${DRIVER_VERSION}-1
  else
    dnf install -y nvidia-fabric-manager-${DRIVER_VERSION}-1
  fi
}

nscq_install() {
  if [ "$DRIVER_BRANCH" -ge "590" ]; then
    dnf install -y libnvidia-nscq-${DRIVER_VERSION}-1.el9
  elif [ "$DRIVER_BRANCH" -ge "580" ]; then
    dnf install -y libnvidia-nscq-${DRIVER_VERSION}-1
  else
    dnf install -y libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
  fi
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    if [ "$DRIVER_BRANCH" -ge "590" ]; then
      dnf install -y libnvsdm-${DRIVER_VERSION}-1.el9
      return 0
    elif [ "$DRIVER_BRANCH" -ge "580" ]; then
      dnf install -y libnvsdm-${DRIVER_VERSION}-1
      return 0
    fi
    if [ "$DRIVER_BRANCH" -ge "570" ]; then
      dnf install -y libnvsdm-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
      return 0
    fi
  fi
}

nvlink5_pkgs_install() {
  if [ "$DRIVER_BRANCH" -ge "550" ]; then
    dnf install -y infiniband-diags nvlsm
  fi
}

imex_install() {
  if [ "$DRIVER_BRANCH" -ge "590" ]; then
    dnf install -y nvidia-imex-${DRIVER_VERSION}-1.el9
  elif [ "$DRIVER_BRANCH" -ge "580" ]; then
    dnf install -y nvidia-imex-${DRIVER_VERSION}-1
  elif [ "$DRIVER_BRANCH" -ge "550" ]; then
    dnf install -y nvidia-imex-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
  fi
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      dnf module enable -y nvidia-driver:${DRIVER_BRANCH}-dkms

      fabricmanager_install
      nscq_install
      nvsdm_install
      nvlink5_pkgs_install
      imex_install
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
