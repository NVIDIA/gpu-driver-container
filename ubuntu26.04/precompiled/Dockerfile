ARG BASE_IMAGE=ubuntu:resolute-20260421
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_BRANCH=580
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=580.126.20
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG KERNEL_VERSION=7.0.0-12-generic
ENV KERNEL_VERSION=$KERNEL_VERSION

ENV NVIDIA_VISIBLE_DEVICES=void

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

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

# Fetch GPG keys for CUDA repo
RUN rm -f /etc/apt/sources.list.d/cuda* && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/cuda-keyring_1.1-1_all.deb -o cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    rm -f cuda-keyring_1.1-1_all.deb

RUN usermod -o -u 0 -g 0 _apt

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get --only-upgrade -y install ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

COPY ubuntu26.04/precompiled/nvidia-driver /usr/local/bin

ADD ubuntu26.04/precompiled/local-repo.sh /tmp

RUN mkdir -p /usr/local/repos && \
    /tmp/local-repo.sh download_driver_package_deps && \
    /tmp/local-repo.sh build_local_apt_repo && \
    /tmp/local-repo.sh fetch_nvidia_installer && \
    # Remove all other ubuntu apt sources to ensure we only pull from the local apt repo
    rm /etc/apt/sources.list.d/*

WORKDIR  /drivers

ENTRYPOINT ["nvidia-driver", "init"]
