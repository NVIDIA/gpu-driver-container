#!/bin/bash
# Copyright (c) 2021-2023, NVIDIA CORPORATION. All rights reserved.

set -eu

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

  dnf install -y 'dnf-command(config-manager)'
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
  if [ "${DRIVER_BRANCH}" -ge "620" ]; then
    local fabricmanager_direct_version="2.0.0"
    dnf install -y "nvidia-fabricmanager-direct-${fabricmanager_direct_version}*" "nvidia-fabricmanager-direct-devel-${fabricmanager_direct_version}*" "libnvidia-fmdrv-${DRIVER_VERSION}"
    dnf versionlock add nvidia-fabricmanager-direct nvidia-fabricmanager-direct-devel libnvidia-fmdrv
    return 0
  fi
  dnf install -y nvidia-fabricmanager-${DRIVER_VERSION} nvidia-fabric-manager-devel-${DRIVER_VERSION}
  dnf versionlock add nvidia-fabricmanager nvidia-fabric-manager-devel
}

nscq_install() {
  dnf install -y libnvidia-nscq-${DRIVER_VERSION}
  dnf versionlock add libnvidia-nscq
}

nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    dnf install -y libnvsdm-${DRIVER_VERSION}
    dnf versionlock add libnvsdm
  fi
}

nvlink5_pkgs_install() {
  dnf install -y infiniband-diags nvlsm
}

imex_install() {
  if [ "${DRIVER_BRANCH}" -ge "620" ]; then
    local imex_direct_version="2.0.0"
    dnf install -y "nvidia-imex-direct-${imex_direct_version}*" "libnvidia-imex-${DRIVER_VERSION}"
    dnf versionlock add nvidia-imex-direct libnvidia-imex
    return 0
  fi
  dnf install -y nvidia-imex-${DRIVER_VERSION}
  dnf versionlock add nvidia-imex
}

setup_local_driver_repo() {
  local rpms gpg_key gpg_key_pkg
  rpms=(/tmp/local-repo/nvidia-driver-local-repo-rhel8-"${DRIVER_VERSION}"-*."${DRIVER_ARCH}".rpm)
  if [ "${#rpms[@]}" -ne 1 ] || [ ! -f "${rpms[0]}" ]; then
    echo "LOCAL_DRIVER=true but expected exactly one local driver repo package for ${DRIVER_VERSION} (${TARGETARCH}) in drivers/" >&2
    exit 1
  fi
  LOCAL_DRIVER_REPO_PKG=$(rpm -qp --queryformat '%{NAME}' "${rpms[0]}")
  rpm -i "${rpms[0]}"
  gpg_key=$(ls "/var/${LOCAL_DRIVER_REPO_PKG}"/*.pub)
  gpg_key_pkg=gpg-pubkey-$(basename "${gpg_key}" .pub | tr '[:upper:]' '[:lower:]')
  LOCAL_DRIVER_REPO_GPG_KEY_PKG=""
  if ! rpm -q "${gpg_key_pkg}" >/dev/null; then
    rpm --import "${gpg_key}"
    LOCAL_DRIVER_REPO_GPG_KEY_PKG=${gpg_key_pkg}
  fi
}

remove_local_driver_repo() {
  rpm -e "${LOCAL_DRIVER_REPO_PKG}"
  if [ -n "${LOCAL_DRIVER_REPO_GPG_KEY_PKG}" ]; then
    rpm -e "${LOCAL_DRIVER_REPO_GPG_KEY_PKG}"
  fi
  rm -rf "/var/${LOCAL_DRIVER_REPO_PKG:?}"
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" != "vgpu" ]; then
      if [ "$LOCAL_DRIVER" = "true" ]; then
        setup_local_driver_repo
      fi

      if [ "${DRIVER_BRANCH}" -ge "615" ]; then
        DRIVER_MODULE_STREAM="${DRIVER_BRANCH}-open"
      else
        DRIVER_MODULE_STREAM="${DRIVER_BRANCH}-dkms"
      fi
      dnf module enable -y "nvidia-driver:${DRIVER_MODULE_STREAM}"
      dnf install -y 'dnf-command(versionlock)'

      fabricmanager_install
      nscq_install
      nvsdm_install
      nvlink5_pkgs_install
      imex_install

      if [ "$LOCAL_DRIVER" = "true" ]; then
        remove_local_driver_repo
      fi

      rm -rf /usr/share/doc/*
      dnf clean all
  fi
}

setup_cuda_repo() {
    if [ "$LOCAL_DRIVER" = "true" ]; then
        return 0
    fi
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa};
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/${OS_ARCH}/cuda-rhel8.repo
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
