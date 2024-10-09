#!/usr/bin/env bash

set -eu

download_installer () {
    DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run && \
    chmod +x  NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run;
}

dep_install () {
    if [ "$TARGETARCH" = "amd64" ]; then
        yum update -y && yum install -y \
            yum-utils \
            gcc \
            make \
            glibc-devel \
            ca-certificates \
            kmod \
            file \
            elfutils-libelf-devel \
            libglvnd-devel \
            shadow-utils \
            pkgconfig && \
            yum clean all
    fi
}

repo_setup () {
    if [ "$TARGETARCH" = "amd64" ]; then

        yum update -y --skip-broken && \
        yum install -y shadow-utils dnf-utils --skip-broken

        echo "[main]
        name=Main Repository
        baseurl=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64
        gpgcheck=1
        enabled=1
        gpgkey=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/D42D0685.pub" > /etc/yum.repos.d/main.repo && \

        # Updates Repository
        echo "[updates]
        name=Updates Repository
        baseurl=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64
        gpgcheck=1
        enabled=1
        gpgkey=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/D42D0685.pub" > /etc/yum.repos.d/updates.repo && \

        # Security Repository
        echo "[security]
        name=Security Repository
        baseurl=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64
        gpgcheck=1
        enabled=1
        gpgkey=gpgkey=https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/D42D0685.pub" > /etc/yum.repos.d/security.repo && \

        usermod -o -u 0 -g 0 nobody
        yum clean all && yum makecache
    else
        echo "TARGETARCH doesn't match a known arch target"
        exit 1
    fi
}

nvswitch_dep_installer() {
    version_array=(${DRIVER_VERSION//./ })
    DRIVER_BRANCH=${version_array[0]}
    if [ ${version_array[0]} -ge 470 ] || ([ ${version_array[0]} == 460 ] && [ ${version_array[1]} -ge 91 ]); then
      fm_pkg=nvidia-fabric-manager-${DRIVER_VERSION}-1
    else \
      fm_pkg=nvidia-fabricmanager-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
    fi; \
    nscq_pkg=libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION}-1
    yum install -y \
        ${fm_pkg} \
        ${nscq_pkg}
    rm -rf /var/cache/yum/*
}

if [ "$1" = "reposetup" ]; then
  repo_setup
elif [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "download_installer" ]; then
  download_installer
elif [ "$1" = "nvswitch_depinstall" ]; then
 nvswitch_dep_installer  
else
  echo "Unknown function: $1"
  exit 1
fi

