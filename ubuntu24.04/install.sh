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
    curl -fSsL "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${OS_ARCH}/cuda-keyring_1.1-1_all.deb" -o cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
}

fabricmanager_install() {
  local fabricmanager_package_name
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    fabricmanager_package_name=nvidia-fabricmanager
  else
    fabricmanager_package_name=nvidia-fabricmanager-${DRIVER_BRANCH}
  fi
  apt-get install -y --no-install-recommends ${fabricmanager_package_name}=${DRIVER_VERSION}*
  apt-mark hold ${fabricmanager_package_name}
}

nscq_install() {
  local nscq_package_name
  if [ "$DRIVER_BRANCH" -ge "580" ]; then
    nscq_package_name=libnvidia-nscq
  else
    nscq_package_name=libnvidia-nscq-${DRIVER_BRANCH}
  fi
  apt-get install -y --no-install-recommends ${nscq_package_name}=${DRIVER_VERSION}*
  apt-mark hold ${nscq_package_name}
}

# libnvsdm packages are not available for arm64
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
    apt-get install -y --no-install-recommends ${nvsdm_package_name}=${DRIVER_VERSION}*
    apt-mark hold ${nvsdm_package_name}
  fi
}

nvlink5_pkgs_install() {
  if [ "$DRIVER_BRANCH" -ge "570" ]; then
    apt-get install -y --no-install-recommends nvlsm infiniband-diags
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
  apt-get install -y --no-install-recommends ${imex_package_name}=${DRIVER_VERSION}*
  apt-mark hold ${imex_package_name}
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      apt-get update

      fabricmanager_install
      nscq_install

      if [ "$TARGETARCH" = "amd64" ]; then
        nvsdm_install
      fi

      nvlink5_pkgs_install
      imex_install

      rm -rf /var/lib/apt/lists/*
  fi
}

if [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "download_installer" ]; then
  download_installer
elif [ "$1" = "extra_pkgs_install" ]; then
  extra_pkgs_install
elif [ "$1" = "setup_cuda_repo" ]; then
  setup_cuda_repo
else
  echo "Unknown function: $1"
  exit 1
fi
