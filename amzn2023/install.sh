#!/usr/bin/env bash

set -eu

download_installer () {
    DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run && \
    chmod +x  NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run;
}

dep_install () {
    if [ "$TARGETARCH" = "amd64" ]; then
        DRIVER_ARCH=${TARGETARCH/amd64/x86_64}
        dnf update -y && dnf install -y \
            gcc \
            make \
            glibc-devel \
            ca-certificates \
            kmod \
            file \
            elfutils-libelf-devel \
            libglvnd-devel \
            shadow-utils \
            util-linux \
            tar \
            rpm-build \
            dnf-utils \
            pkgconfig && \
            dnf clean all && \
            rm -rf /var/cache/yum/*
    fi
}

repo_setup () {
    if [ "$TARGETARCH" = "amd64" ]; then
      echo "[cuda-amzn2023-x86_64]
name=cuda-amzn2023-x86_64
baseurl=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/$DRIVER_ARCH
enabled=1
gpgcheck=1
gpgkey=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/$DRIVER_ARCH/D42D0685.pub" > /etc/yum.repos.d/cuda.repo && \
      usermod -o -u 0 -g 0 nobody
    else
        echo "TARGETARCH doesn't match a known arch target"
        exit 1
    fi
}

if [ "$1" = "reposetup" ]; then
  repo_setup
elif [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "download_installer" ]; then
  download_installer
else
  echo "Unknown function: $1"
  exit 1
fi

