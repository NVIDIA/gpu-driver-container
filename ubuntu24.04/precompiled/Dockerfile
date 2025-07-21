FROM nvcr.io/nvidia/cuda:12.9.1-base-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_BRANCH=550
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=550.90.12
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG KERNEL_VERSION=6.8.0-44-generic
ENV KERNEL_VERSION=$KERNEL_VERSION

ENV NVIDIA_VISIBLE_DEVICES=void

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        gpg \
        kmod \
        file \
        libelf-dev \
        libglvnd-dev \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Fetch GPG keys for CUDA repo
RUN apt-key del 3bf863cc && \
    rm /etc/apt/sources.list.d/cuda.list && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub | gpg --dearmor -o /etc/apt/keyrings/cuda.pub && \
    echo "deb [signed-by=/etc/apt/keyrings/cuda.pub] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

RUN usermod -o -u 0 -g 0 _apt

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
    # Remove all other ubuntu apt sources to ensure we only pull from the local apt repo
    rm /etc/apt/sources.list.d/*

WORKDIR  /drivers

ENTRYPOINT ["nvidia-driver", "init"]
