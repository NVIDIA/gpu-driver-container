ARG BASE_IMAGE=ubuntu:noble-20250910

FROM ${BASE_IMAGE} as build

ARG TARGETARCH
ARG GOLANG_VERSION

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE

SHELL ["/bin/bash", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        git && \
    rm -rf /var/lib/apt/lists/*



# download appropriate binary based on the target architecture for multi-arch builds
RUN OS_ARCH=${TARGETARCH/x86_64/amd64} && OS_ARCH=${OS_ARCH/aarch64/arm64} && \
    curl https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz \
    | tar -C /usr/local -xz

ENV PATH /usr/local/go/bin:$PATH

WORKDIR /work

RUN if [ "$DRIVER_TYPE" = "vgpu" ]; then \
    git clone https://github.com/NVIDIA/gpu-driver-container driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work; fi

FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ENV DEBIAN_FRONTEND=noninteractive

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE
ARG DRIVER_BRANCH=550
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG VGPU_LICENSE_SERVER_TYPE=NLS
ENV VGPU_LICENSE_SERVER_TYPE=$VGPU_LICENSE_SERVER_TYPE
# Enable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=true
ENV DISABLE_VGPU_VERSION_CHECK=$DISABLE_VGPU_VERSION_CHECK
ENV NVIDIA_VISIBLE_DEVICES=void

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN echo "TARGETARCH=$TARGETARCH"

ADD install.sh /tmp

RUN usermod -o -u 0 -g 0 _apt && \
    /tmp/install.sh depinstall && /tmp/install.sh setup_cuda_repo

COPY nvidia-driver /usr/local/bin

COPY --from=build /work/vgpu-util* /usr/local/bin

ADD drivers drivers/

# Fetch the installer, fabricmanager and libnvidia-nscq automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
    cd drivers && \
    /tmp/install.sh download_installer; fi

RUN /tmp/install.sh extra_pkgs_install

WORKDIR  /drivers

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get upgrade -y ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

ENTRYPOINT ["nvidia-driver", "init"]
