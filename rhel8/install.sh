#!/bin/bash
# Copyright (c) 2021-2023, NVIDIA CORPORATION. All rights reserved.

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

if [ "$1" = "nvinstall" ]; then
  nvidia_installer
elif [ "$1" = "depinstall" ]; then
  dep_installer
else
  echo "Unknown function: $1"
fi
