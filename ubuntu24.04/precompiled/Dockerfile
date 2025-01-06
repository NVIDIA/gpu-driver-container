FROM nvcr.io/nvidia/cuda:12.6.2-base-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETARCH
ARG GOLANG_VERSION
ARG DRIVER_BRANCH=550
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=550.90.12
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG KERNEL_VERSION=6.8.0-44-generic
ENV KERNEL_VERSION=$KERNEL_VERSION

ENV NVIDIA_VISIBLE_DEVICES=void

SHELL ["/bin/bash", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        git \
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

# download appropriate binary based on the target architecture for multi-arch builds
RUN OS_ARCH=${TARGETARCH/x86_64/amd64} && OS_ARCH=${OS_ARCH/aarch64/arm64} && \
    curl https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz \
    | tar -C /usr/local -xz

ENV PATH=/usr/local/go/bin:$PATH

RUN git clone https://github.com/NVIDIA/gpu-driver-container driver && \
    go build -C driver/gpu-driver-util -o gpu-driver-util && \
    mv driver/gpu-driver-util/gpu-driver-util /usr/local/bin && \
    rm -rf driver

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get upgrade -y ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# update pkg cache and install pkgs for userspace driver libs
RUN apt-get update && apt-get install -y --download-only --no-install-recommends nvidia-driver-${DRIVER_BRANCH}-server \
    nvidia-fabricmanager-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 \
    libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 && \
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
