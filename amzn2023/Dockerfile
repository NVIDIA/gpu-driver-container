ARG CUDA_VERSION=latest

FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-base-amzn2023 AS build
FROM amazonlinux:2

ARG TARGETARCH
ARG CUDA_VERSION
    
SHELL ["/bin/bash", "-c"]

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda*

RUN yum update -y && yum install -y yum-utils && \
    yum-config-manager --setopt=skip_missing_names_on_install=False && \
    yum install -y \
    gcc \
    gcc-c++ \
    make \
    ca-certificates \
    git -y && \
    yum clean all

ENV GOLANG_VERSION=1.23.1

# download appropriate binary based on the target architecture for multi-arch builds
RUN OS_ARCH=$(echo ${TARGETARCH} | sed 's/x86_64/amd64/' ) && \
    curl -s https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz \
    | tar -C /usr/local -xz

ENV PATH /usr/local/go/bin:$PATH

WORKDIR /work

RUN git clone https://github.com/NVIDIA/gpu-driver-container driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work
COPY --from=build /work/vgpu-util /usr/local/bin

FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-base-amzn2023

SHELL ["/bin/bash", "-c"]

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION

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

RUN echo "TARGETARCH=$TARGETARCH"

ADD install.sh /tmp

RUN /tmp/install.sh reposetup && /tmp/install.sh depinstall && \
    curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    chmod +x /usr/local/bin/donkey

COPY nvidia-driver /usr/local/bin

ADD drivers drivers/

# Fetch the installer automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
    cd drivers && \
    /tmp/install.sh download_installer; fi

RUN if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$TARGETARCH" != "arm64" ]; then \
    yum update -y && \
    yum install -y \
    nvidia-fabric-manager-${DRIVER_VERSION}-1 \
    libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION}-1; fi

WORKDIR  /drivers

ARG PUBLIC_KEY=empty
COPY ${PUBLIC_KEY} kernel/pubkey.x509

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        yum update -y && yum install -y yum-utils && \
        yum-config-manager --setopt=skip_missing_names_on_install=False && \
        yum install -y \
        ${CVE_UPDATES} && \
        yum clean all; fi

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda*

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

ENTRYPOINT ["nvidia-driver", "init"]
