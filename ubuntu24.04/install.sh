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
            gpg \
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
            gpg \
            kmod \
            file \
            libelf-dev \
            libglvnd-dev && \
        rm -rf /var/lib/apt/lists/*
    fi
}

setup_cuda_repo() {
    # Remove any existing CUDA GPG keys that are unconditionally trusted by apt
    apt-key del 3bf863cc
    rm /etc/apt/sources.list.d/cuda.list

    # Fetch public CUDA GPG key and configure apt to only use this key when downloading CUDA packages
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa};
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${OS_ARCH}/3bf863cc.pub | gpg --dearmor -o /etc/apt/keyrings/cuda.pub;
    echo "deb [signed-by=/etc/apt/keyrings/cuda.pub] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${OS_ARCH} /" > /etc/apt/sources.list.d/cuda.list
}

if [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "download_installer" ]; then
  download_installer
elif [ "$1" = "setup_cuda_repo" ]; then
  setup_cuda_repo
else
  echo "Unknown function: $1"
  exit 1
fi
