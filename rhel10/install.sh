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
        file \
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
        file \
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
        file \
        kmod
  fi

  if ! dnf install -y 'dnf-command(config-manager)'; then
    dnf install -y dnf5-plugins
  fi

  OS_RELEASE_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
  if [ "$OS_RELEASE_ID" = "rocky" ]; then
    dnf config-manager --set-enabled crb
  elif [ "$OS_RELEASE_ID" = "rhel" ]; then
    dnf config-manager --set-enabled codeready-builder-for-rhel-10-${DRIVER_ARCH}-rpms || true
  fi

  # Download unzboot as kernel images are compressed in the zboot format on RHEL 10 arm64
  # unzboot is only available on the EPEL RPM repo
  if [ "$DRIVER_ARCH" = "aarch64" ]; then
    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-10
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
    dnf config-manager --enable epel
    # Try to install unzboot from EPEL. If it is not available yet, build it
    # from source because RHEL/Rocky 10 arm64 kernel images require it.
    if ! dnf install -y unzboot; then
      echo "unzboot package not available in current EPEL version; building from source."

      # Install meson build dependencies
      if dnf install -y git gcc meson ninja-build glib2-devel zlib-devel libzstd-devel; then
        if command -v meson >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
          if git clone https://github.com/eballetbo/unzboot.git /tmp/unzboot-src 2>/dev/null; then
            if meson setup /tmp/unzboot-src/build /tmp/unzboot-src && meson compile -C /tmp/unzboot-src/build; then
              cp /tmp/unzboot-src/build/unzboot /usr/bin/unzboot
              chmod +x /usr/bin/unzboot
              runtime_pkgs=$(ldd /usr/bin/unzboot | awk '/=> \// { print $3 } /^\// { print $1 }' | xargs -r rpm -q --whatprovides | sort -u)
              if [ -n "$runtime_pkgs" ]; then
                dnf install -y $runtime_pkgs
              fi
              echo "Built and installed unzboot from source"
            else
              echo "Error: Failed to build unzboot from source." >&2
              rm -rf /tmp/unzboot-src
              return 1
            fi
            rm -rf /tmp/unzboot-src
          else
            echo "Error: Unable to clone unzboot source." >&2
            return 1
          fi
        else
          echo "Error: meson or ninja not available." >&2
          return 1
        fi

        dnf remove -y git meson ninja-build glib2-devel zlib-devel libzstd-devel || true
        dnf autoremove -y || true
      else
        echo "Error: Could not install build dependencies for unzboot." >&2
        return 1
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

# libnvsdm packages are not available for arm64
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
  rpms=(/tmp/local-repo/nvidia-driver-local-repo-rhel10-"${DRIVER_VERSION}"-*."${DRIVER_ARCH}".rpm)
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
