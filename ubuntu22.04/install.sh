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
            gnupg \
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
            gnupg \
            libelf-dev \
            libglvnd-dev && \
        rm -rf /var/lib/apt/lists/*
    fi
}

setup_cuda_repo() {
    # Fetch public CUDA GPG key and configure apt to only use this key when downloading CUDA packages
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa};
    curl -fSsL "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/${OS_ARCH}/cuda-keyring_1.1-1_all.deb" -o cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
}

fabricmanager_install() {
  apt-get install -y --no-install-recommends \
      nvidia-fabricmanager=${DRIVER_VERSION}* \
      nvidia-fabricmanager-dev=${DRIVER_VERSION}*
  apt-mark hold nvidia-fabricmanager nvidia-fabricmanager-dev
}

nscq_install() {
  apt-get install -y --no-install-recommends libnvidia-nscq=${DRIVER_VERSION}*
  apt-mark hold libnvidia-nscq
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    apt-get install -y --no-install-recommends libnvsdm=${DRIVER_VERSION}*
    apt-mark hold libnvsdm
  fi
}

nvlink5_pkgs_install() {
  apt-get install -y --no-install-recommends nvlsm infiniband-diags
}

imex_install() {
  apt-get install -y --no-install-recommends nvidia-modprobe=${DRIVER_VERSION}* nvidia-imex=${DRIVER_VERSION}*
  apt-mark hold nvidia-modprobe nvidia-imex
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" == "vgpu" ]; then
    return 0
  fi

  if [ "$LOCAL_DRIVER" == "true" ]; then
    # TODO: add nvsdm, nvlink5, and imex packages here
    dpkg -i drivers/nvidia-fabricmanager-${DRIVER_BRANCH}_${DRIVER_VERSION}*.deb
    dpkg -i drivers/libnvidia-nscq-${DRIVER_BRANCH}_${DRIVER_VERSION}*.deb
    return 0
  fi

  apt-get update

  fabricmanager_install
  nscq_install
  nvsdm_install
  nvlink5_pkgs_install
  imex_install

  rm -rf /var/lib/apt/lists/*
}

if [ "$1" = "setup_cuda_repo" ]; then
  setup_cuda_repo
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

