FROM nvcr.io/nvidia/cuda:12.9.1-base-ubuntu22.04 as build

ARG TARGETARCH
ARG GOLANG_VERSION

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

RUN git clone https://github.com/NVIDIA/gpu-driver-container driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work

FROM nvcr.io/nvidia/cuda:12.9.1-base-ubuntu22.04

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
ARG DRIVER_BRANCH=535
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

# Fetch GPG keys for CUDA repo
RUN apt-key del 7fa2af80 && OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa} && \
    apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/${OS_ARCH}/3bf863cc.pub"

RUN /tmp/install.sh reposetup && /tmp/install.sh depinstall && \
    curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    chmod +x /usr/local/bin/donkey

COPY nvidia-driver /usr/local/bin

COPY --from=build /work/vgpu-util /usr/local/bin

ADD drivers drivers/

# Fetch the installer, fabricmanager and libnvidia-nscq automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
    cd drivers && \
    /tmp/install.sh download_installer && \
    apt-get update && \
    apt-get install -y --no-install-recommends nvidia-fabricmanager-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 \
    libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 && \
    rm -rf /var/lib/apt/lists/*; fi

RUN if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$DRIVER_BRANCH" -ge "550" ]; then \
    apt-get update && \
    apt-get install -y --no-install-recommends nvlsm infiniband-diags \
    nvidia-imex-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 && \
    rm -rf /var/lib/apt/lists/*; fi

# libnvsdm packages are not available for arm64
RUN if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$DRIVER_BRANCH" -ge "560" ] && [ "$TARGETARCH" != "arm64" ]; then \
    apt-get update && \
    apt-get install -y --no-install-recommends libnvsdm-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 && \
    rm -rf /var/lib/apt/lists/*; fi

WORKDIR  /drivers

ARG PUBLIC_KEY=empty
COPY ${PUBLIC_KEY} kernel/pubkey.x509

# Install the gcc-12 package in Ubuntu 22.04 as Kernels with versions 5.19.x and 6.5.x need gcc 12.3.0 for compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc-12 g++-12 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12 && \
    rm -rf /var/lib/apt/lists/*


# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get upgrade -y ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

ENTRYPOINT ["nvidia-driver", "init"]
