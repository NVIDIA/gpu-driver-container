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

  if ! dnf install -y 'dnf-command(config-manager)'; then
    dnf install -y dnf5-plugins
  fi

  # Download unzboot as kernel images are compressed in the zboot format on RHEL 10 arm64
  # unzboot is only available on the EPEL RPM repo
  if [ "$DRIVER_ARCH" = "aarch64" ]; then
    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-10
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
    dnf config-manager --enable epel
    # Try to install unzboot, but continue if not available (only in EPEL 10.2+)
    if ! dnf install -y unzboot; then
      echo "Warning: unzboot package not available in current EPEL version; continuing without it."

      # Install meson build dependencies
      if dnf install -y git gcc meson ninja-build glib2-devel zlib-devel libzstd-devel; then
        if command -v meson >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
          if git clone https://github.com/eballetbo/unzboot.git /tmp/unzboot-src 2>/dev/null; then
            if meson setup /tmp/unzboot-src/build /tmp/unzboot-src && meson compile -C /tmp/unzboot-src/build; then
              cp /tmp/unzboot-src/build/unzboot /usr/bin/unzboot
              chmod +x /usr/bin/unzboot
              echo "Built and installed unzboot from source"
            else
              echo "Warning: Failed to build unzboot from source; continuing without it."
            fi
            rm -rf /tmp/unzboot-src
          else
            echo "Warning: Unable to clone unzboot source; continuing without it."
          fi
        else
          echo "Warning: meson or ninja not available; continuing without unzboot."
        fi

        dnf remove -y git meson ninja-build glib2-devel zlib-devel libzstd-devel || true
        dnf autoremove -y || true
      else
        echo "Warning: Could not install build dependencies for unzboot; continuing without it."
      fi
    fi
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
  local fabricmanager_package_name=nvidia-fabricmanager
  dnf install -y ${fabricmanager_package_name}-${DRIVER_VERSION}
  dnf versionlock add ${fabricmanager_package_name}
}

nscq_install() {
  local nscq_package_name=libnvidia-nscq
  dnf install -y ${nscq_package_name}-${DRIVER_VERSION}
  dnf versionlock add ${nscq_package_name}
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  local nvsdm_package_name=libnvsdm
  if [ "$TARGETARCH" = "amd64" ]; then
    dnf install -y ${nvsdm_package_name}-${DRIVER_VERSION}
    dnf versionlock add ${nvsdm_package_name}
  fi
}

nvlink5_pkgs_install() {
  dnf install -y infiniband-diags nvlsm
}

imex_install() {
  local imex_package_name=nvidia-imex
  dnf install -y ${imex_package_name}-${DRIVER_VERSION}
  dnf versionlock add ${imex_package_name}
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
    dnf install -y 'dnf-command(versionlock)'

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
