FROM nvcr.io/nvidia/cuda:12.9.1-base-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_BRANCH=535
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=535.247.01
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

RUN if [ "$DRIVER_BRANCH" -ge "550" ]; then \
    apt-get update && \
    apt-get install -y --no-install-recommends nvidia-imex-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 && \
    rm -rf /var/lib/apt/lists/*; fi

COPY nvidia-driver /usr/local/bin

ADD local-repo.sh /tmp

RUN mkdir -p /usr/local/repos && \
    /tmp/local-repo.sh download_driver_package_deps && \
    /tmp/local-repo.sh build_local_apt_repo && \
    /tmp/local-repo.sh fetch_nvidia_installer && \
    # Remove cuda repository to avoid GPG errors
    rm -f /etc/apt/sources.list.d/cuda*

WORKDIR  /drivers

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

ENTRYPOINT ["nvidia-driver", "init"]
