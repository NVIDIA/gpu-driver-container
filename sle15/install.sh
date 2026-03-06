#!/bin/bash
# Copyright (c) 2021-2023, NVIDIA CORPORATION. All rights reserved.

set -eu

DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && DRIVER_ARCH=${DRIVER_ARCH/arm64/aarch64}
echo "DRIVER_ARCH is $DRIVER_ARCH"

download_installer () {
    curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run && \
    chmod +x  NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run;
}

dep_installer () {
  if [ "$TARGETARCH" = "amd64" ]; then
    zypper --non-interactive install -y \
        libglvnd \
        ca-certificates \
        curl \
        gcc \
        make \
        cpio \
        kmod \
        jq
  elif [ "$TARGETARCH" = "ppc64le" ]; then
    zypper --non-interactive install -y \
        libglvnd-glx \
        ca-certificates \
        curl \
        gcc \
        glibc \
        make \
        cpio \
        kmod \
        jq
  fi
  rm -rf /var/cache/zypp/*
}



fabricmanager_install() {
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    zypper --non-interactive install -y --no-recommends nvidia-fabricmanager-${DRIVER_VERSION}-1
  else
    zypper --non-interactive install -y --no-recommends nvidia-fabricmanager-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
  fi
}

nscq_install() {
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    zypper --non-interactive install -y --no-recommends libnvidia-nscq=${DRIVER_VERSION}-1
  else
    zypper --non-interactive install -y --no-recommends libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1
  fi
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "aarch64" ]; then
    if [ "$DRIVER_BRANCH" -ge "580" ]; then
       zypper --non-interactive  install -y --no-recommends libnvsdm=${DRIVER_VERSION}-1
    elif [ "$DRIVER_BRANCH" -ge "570" ]; then
       zypper --non-interactive  install -y --no-recommends libnvsdm-${DRIVER_BRANCH}=${DRIVER_VERSION}-1
    fi
  fi
}

nvlink5_pkgs_install() {
  if [ "$DRIVER_BRANCH" -ge "550" ]; then
    zypper --non-interactive  install -y --no-recommends nvlsm infiniband-diags
  fi
}

imex_install() {
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    zypper --non-interactive  install -y --no-recommends nvidia-imex=${DRIVER_VERSION}-1
  elif [ "$DRIVER_BRANCH" -ge "550" ]; then
    zypper --non-interactive  install -y --no-recommends nvidia-imex-${DRIVER_BRANCH}=${DRIVER_VERSION}-1;
  fi
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      fabricmanager_install
      nscq_install

      echo "extra_pkgs_install $TARGETARCH"
      if [ "$TARGETARCH" = "aarch64" ]; then
        echo "arm shouldn't be entering"
        nvsdm_install
      fi

      #nvlink5_pkgs_install
      imex_install
  fi
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
  else
    echo "DRIVER_ARCH doesn't match a known arch target"
  fi
}

setup_cuda_repo() {
    zypper --non-interactive addrepo https://developer.download.nvidia.com/compute/cuda/repos/sles15/${TARGETARCH/amd64/x86_64} cuda-sles15 && \
    zypper --gpg-auto-import-keys --non-interactive ref
}

if [ "$1" = "nvinstall" ]; then
  nvidia_installer
elif [ "$1" = "depinstall" ]; then
  dep_installer
elif [ "$1" = "download_installer" ]; then
  download_installer
elif [ "$1" = "extrapkgsinstall" ]; then
  extra_pkgs_install
elif [ "$1" = "setup_cuda_repo" ]; then
  setup_cuda_repo
else
  echo "Unknown function: $1"
  exit 1
fi
