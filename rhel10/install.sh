#!/bin/bash
# Copyright (c) 2026, NVIDIA CORPORATION. All rights reserved.

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
        glibc \
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
  rpm --import  https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-10
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
  dnf config-manager --enable epel
  
  # Try to install unzboot, but continue if not available (only in EPEL 10.2+)
  if ! dnf install -y unzboot 2>/dev/null; then
    echo "Warning: unzboot package not available in current EPEL version (requires EPEL 10.2+)"
    echo "Attempting to build unzboot from source..."
    
   # Install meson build dependencies
    dnf install -y git gcc meson ninja-build glib2-devel zlib-devel libzstd-devel || true
    git clone https://github.com/eballetbo/unzboot.git 2>/dev/null
    cd unzboot
    if meson setup build && meson compile -C build; then
      echo "Successfully built unzboot from source"
      cp build/unzboot /usr/bin/unzboot
      chmod +x /usr/bin/unzboot
    else
      echo "Warning: Failed to build unzboot from source. Kernel extraction may fall back to gunzip methods."
    fi
    cd ..
    rm -rf unzboot
    dnf remove -y git meson ninja-build glib2-devel zlib-devel libzstd-devel || true
    dnf autoremove -y || true
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

fabricmanager_install() {
  dnf install -y nvidia-fabricmanager-${DRIVER_VERSION}
}

nscq_install() {
  dnf install -y libnvidia-nscq-${DRIVER_VERSION}
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    dnf install -y libnvsdm-${DRIVER_VERSION}
  fi
}

nvlink5_pkgs_install() {
  dnf install -y infiniband-diags nvlsm
}

imex_install() {
  dnf install -y nvidia-imex-${DRIVER_VERSION}
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then

    fabricmanager_install
    nscq_install
    nvsdm_install
    nvlink5_pkgs_install
    imex_install
  fi
}

setup_cuda_repo() {
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa};
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel10/${OS_ARCH}/cuda-rhel10.repo
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
