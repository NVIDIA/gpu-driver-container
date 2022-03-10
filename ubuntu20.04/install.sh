#!/usr/bin/env bash

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
            libelf-dev \
            libglvnd-dev && \
        rm -rf /var/lib/apt/lists/*
    fi
}

repo_setup () {
    if [ "$TARGETARCH" = "amd64" ]; then
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main universe" > /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal-updates main universe" >> /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal-security main universe" >> /etc/apt/sources.list && \
        usermod -o -u 0 -g 0 _apt
    elif [ "$TARGETARCH" = "arm64" ]; then
        echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal main universe" > /etc/apt/sources.list && \
        echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal-updates main universe" >> /etc/apt/sources.list && \
        echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports focal-security main universe" >> /etc/apt/sources.list && \
        usermod -o -u 0 -g 0 _apt
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

