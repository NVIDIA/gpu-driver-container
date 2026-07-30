#!/usr/bin/env bash

set -eu

LOCAL_REPO_DIR=/usr/local/repos

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
    curl -fSsL "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/${OS_ARCH}/cuda-keyring_1.1-1_all.deb" -o cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    rm -f cuda-keyring_1.1-1_all.deb
}

# Pin the driver metapackage and the extra packages to the exact DRIVER_VERSION release.
pin_driver_version() {
    apt-get update
    apt-get install -y --no-install-recommends nvidia-driver-pinning-${DRIVER_VERSION}
}

# Preinstall the driver userspace: nvidia-headless-no-dkms-open plus the display/codec libraries
# it omits. nvidia-dkms[-open] is left out and installed at container start, so no kernel module
# is registered or built at image build time. zstd is used by dkms to compress built modules
# (kernel modules are zstd-compressed on 26.04) but is not one of its dependencies.
userspace_install() {
    apt-get install -y --no-install-recommends \
        nvidia-headless-no-dkms-open \
        libnvidia-gl \
        libnvidia-decode \
        libnvidia-encode \
        libnvidia-fbc1 \
        libnvidia-extra \
        dkms \
        zstd
}

extra_pkgs_install() {
    # The pinning package constrains the driver-versioned packages (fabricmanager, nscq, imex)
    # to DRIVER_VERSION; nvlsm and infiniband-diags are versioned independently of the driver.
    apt-get install -y --no-install-recommends \
        nvidia-fabricmanager \
        libnvidia-nscq \
        nvidia-imex \
        nvlsm \
        infiniband-diags

    # libnvsdm packages are not available for arm64
    if [ "$TARGETARCH" = "amd64" ]; then
        apt-get install -y --no-install-recommends libnvsdm
    fi
}

# Download the kernel module packages and metapackage shims into a local file: apt repo, then
# remove the CUDA network source so NVIDIA packages resolve only from the local repo at
# container start. Must run last: the preceding install steps need the CUDA network source.
build_module_repo() {
    mkdir -p ${LOCAL_REPO_DIR}
    cd ${LOCAL_REPO_DIR}
    # nvidia-firmware is already installed at build, but the GPU operator mounts a host
    # directory over /lib/firmware at runtime, which hides the installed files. The runtime
    # reinstalls the package from this repo so the files are written into that host directory.
    apt-get download nvidia-dkms-open nvidia-open nvidia-driver-open \
                     nvidia-dkms nvidia-kernel-source nvidia-driver cuda-drivers \
                     nvidia-firmware
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    echo "deb [trusted=yes] file:${LOCAL_REPO_DIR} ./" > /etc/apt/sources.list.d/local-nvidia.list
    rm -f /etc/apt/sources.list.d/cuda*
    rm -rf /var/lib/apt/lists/*
}

# Install the driver payload for the passthrough/baremetal type. The vgpu type installs from a
# user-supplied .run file at container start, so all package setup is skipped.
driver_pkgs_install() {
    if [ "$DRIVER_TYPE" = "vgpu" ]; then
        echo "Skipping driver package install for the vgpu driver type"
        return 0
    fi
    setup_cuda_repo
    pin_driver_version
    userspace_install
    extra_pkgs_install
    build_module_repo
}

if [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "driver_pkgs_install" ]; then
  driver_pkgs_install
else
  echo "Unknown function: $1"
  exit 1
fi
