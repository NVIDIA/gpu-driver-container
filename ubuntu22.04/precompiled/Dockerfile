FROM nvcr.io/nvidia/cuda:12.6.2-base-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG DRIVER_BRANCH=535
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=535.216.01
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG KERNEL_VERSION=5.15.0-116-generic
ENV KERNEL_VERSION=$KERNEL_VERSION

ENV NVIDIA_VISIBLE_DEVICES=void

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Fetch GPG keys for CUDA repo
RUN apt-key del 7fa2af80 && \
    apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub"

RUN dpkg --add-architecture i386 && \
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

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu jammy-updates main restricted" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu jammy-security main restricted" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

RUN curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    chmod +x /usr/local/bin/donkey

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get upgrade -y ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# update pkg cache and install pkgs for userspace driver libs
RUN apt-get update && apt-get install -y --no-install-recommends nvidia-driver-${DRIVER_BRANCH}-server \
    nvidia-fabricmanager-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 \
    libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 && \
    apt-get purge -y \
    libnvidia-egl-wayland1 \
    nvidia-dkms-${DRIVER_BRANCH}-server \
    nvidia-kernel-source-${DRIVER_BRANCH}-server \
    xserver-xorg-video-nvidia-${DRIVER_BRANCH}-server && \
    rm -rf /var/lib/apt/lists/*;

# update pkg cache and download pkgs for driver module installation during runtime.
# this is done to avoid shipping .ko files.
# avoid cleaning the cache after this to retain these packages during runtime.
RUN apt-get update && apt-get install --download-only --no-install-recommends -y linux-objects-nvidia-${DRIVER_BRANCH}-server-${KERNEL_VERSION} \
    linux-signatures-nvidia-${KERNEL_VERSION} \
    linux-modules-nvidia-${DRIVER_BRANCH}-server-${KERNEL_VERSION} \
    # add support for nvidia open source driver packages during runtime
    linux-modules-nvidia-${DRIVER_BRANCH}-server-open-${KERNEL_VERSION}

COPY nvidia-driver /usr/local/bin

WORKDIR  /drivers

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

ENTRYPOINT ["nvidia-driver", "init"]
