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
    if [ "$LOCAL_DRIVER" = "true" ]; then
        return 0
    fi
    # Fetch public CUDA GPG key and configure apt to only use this key when downloading CUDA packages
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa};
    curl -fSsL "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/${OS_ARCH}/cuda-keyring_1.1-1_all.deb" -o cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
}

fabricmanager_install() {
  if [ "${DRIVER_BRANCH}" -ge "620" ]; then
    apt-get install -y --no-install-recommends nvidia-fabricmanager-direct nvidia-fabricmanager-direct-dev
    apt-mark hold nvidia-fabricmanager-direct nvidia-fabricmanager-direct-dev libnvidia-fmdrv1
    return 0
  fi
  apt-get install -y --no-install-recommends \
      nvidia-fabricmanager=${DRIVER_VERSION}* \
      nvidia-fabricmanager-dev=${DRIVER_VERSION}*
  apt-mark hold nvidia-fabricmanager nvidia-fabricmanager-dev
}

nscq_install() {
  apt-get install -y --no-install-recommends libnvidia-nscq=${DRIVER_VERSION}*
  apt-mark hold libnvidia-nscq
}

# libnvsdm packages are not available for arm64
nvsdm_install() {
  if [ "$TARGETARCH" = "amd64" ]; then
    apt-get install -y --no-install-recommends libnvsdm=${DRIVER_VERSION}*
    apt-mark hold libnvsdm
  fi
}

nvlink5_pkgs_install() {
  apt-get install -y --no-install-recommends nvlsm infiniband-diags
}

imex_install() {
  if [ "${DRIVER_BRANCH}" -ge "620" ]; then
    apt-get install -y --no-install-recommends nvidia-imex-direct
    apt-mark hold nvidia-modprobe nvidia-imex-direct libnvidia-imex1
    return 0
  fi
  apt-get install -y --no-install-recommends nvidia-modprobe=${DRIVER_VERSION}* nvidia-imex=${DRIVER_VERSION}*
  apt-mark hold nvidia-modprobe nvidia-imex
}

setup_local_driver_repo() {
  local repo_debs repo_keyring
  repo_debs=(/tmp/local-repo/nvidia-driver-local-repo-ubuntu2204-"${DRIVER_VERSION}"_*_"${TARGETARCH}".deb)
  if [ "${#repo_debs[@]}" -ne 1 ] || [ ! -f "${repo_debs[0]}" ]; then
    echo "LOCAL_DRIVER=true but expected exactly one local driver repo package for ${DRIVER_VERSION} (${TARGETARCH}) in drivers/" >&2
    exit 1
  fi
  LOCAL_DRIVER_REPO_PKG=$(dpkg-deb -f "${repo_debs[0]}" Package)
  dpkg -i "${repo_debs[0]}"
  repo_keyring=$(ls "/var/${LOCAL_DRIVER_REPO_PKG}"/nvidia-driver-local-*-keyring.gpg)
  LOCAL_DRIVER_REPO_KEYRING=/usr/share/keyrings/$(basename "${repo_keyring}")
  cp "${repo_keyring}" "${LOCAL_DRIVER_REPO_KEYRING}"
}

remove_local_driver_repo() {
  apt-get purge -y "${LOCAL_DRIVER_REPO_PKG}"
  rm -f "${LOCAL_DRIVER_REPO_KEYRING}"
  rm -rf "/var/${LOCAL_DRIVER_REPO_PKG:?}"
}

extra_pkgs_install() {
  if [ "$DRIVER_TYPE" == "vgpu" ]; then
    return 0
  fi

  if [ "$LOCAL_DRIVER" = "true" ]; then
    setup_local_driver_repo
  fi

  apt-get update

  if [ "${DRIVER_BRANCH}" -ge "620" ]; then
    apt-get install -y --no-install-recommends "nvidia-driver-pinning-${DRIVER_VERSION}"
  fi

  fabricmanager_install
  nscq_install
  nvsdm_install
  nvlink5_pkgs_install
  imex_install

  if [ "$LOCAL_DRIVER" = "true" ]; then
    remove_local_driver_repo
  fi

  rm -rf /var/lib/apt/lists/*
}

if [ "$1" = "setup_cuda_repo" ]; then
  setup_cuda_repo
elif [ "$1" = "depinstall" ]; then
  dep_install
elif [ "$1" = "extra_pkgs_install" ]; then
  extra_pkgs_install
elif [ "$1" = "download_installer" ]; then
  download_installer
else
  echo "Unknown function: $1"
  exit 1
fi

