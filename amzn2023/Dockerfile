FROM nvcr.io/nvidia/cuda:12.6.2-base-amzn2023 AS build

ARG TARGETARCH

SHELL ["/bin/bash", "-c"]

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda*

RUN dnf update -y && dnf makecache && \
    dnf install -y \
    gcc \
    gcc-c++ \
    make \
    ca-certificates \
    git \
    tar && \
    dnf clean all && rm -rf /var/cache/yum/*

ENV GOLANG_VERSION=1.23.2

# download appropriate binary based on the target architecture for multi-arch builds
RUN curl https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-${TARGETARCH}.tar.gz \
    | tar -C /usr/local -xz

ENV PATH /usr/local/bin:$PATH
ENV PATH /usr/local/go/bin:$PATH

WORKDIR /work

RUN git clone https://github.com/NVIDIA/gpu-driver-container driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work

FROM nvcr.io/nvidia/cuda:12.6.2-base-amzn2023

SHELL ["/bin/bash", "-c"]

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ENV DRIVER_ARCH=${TARGETARCH/amd64/x86_64}
ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE
ARG DRIVER_BRANCH=560
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG VGPU_LICENSE_SERVER_TYPE=NLS
ENV VGPU_LICENSE_SERVER_TYPE=$VGPU_LICENSE_SERVER_TYPE
# Enable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=true
ENV DISABLE_VGPU_VERSION_CHECK=$DISABLE_VGPU_VERSION_CHECK
ENV NVIDIA_VISIBLE_DEVICES=void

RUN echo "TARGETARCH=$TARGETARCH"

ADD install.sh /tmp

RUN NVIDIA_GPGKEY_SUM=d0664fbbdb8c32356d45de36c5984617217b2d0bef41b93ccecd326ba3b80c87 && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/${DRIVER_ARCH}/D42D0685.pub | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict - && \
    curl -fsSL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/${DRIVER_ARCH}/cuda-amzn2023.repo

RUN dnf clean all && dnf makecache && dnf update -y && dnf install -y shadow-utils
RUN /tmp/install.sh reposetup && /tmp/install.sh depinstall && \
    curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    chmod +x /usr/local/bin/donkey

COPY nvidia-driver /usr/local/bin
COPY --from=build /work/vgpu-util /usr/local/bin

RUN curl -fsSL -o /usr/local/bin/extract-vmlinux https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux && \
    chmod +x /usr/local/bin/extract-vmlinux

ADD drivers drivers/

# Fetch the installer automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
    cd drivers && \
    /tmp/install.sh download_installer; fi

# Check for nvidia-fabric-manager or nvidia-fabricmanager availability and install
RUN if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$TARGETARCH" != "arm64" ]; then \
    dnf install -y nvidia-fabric-manager-${DRIVER_VERSION}-1 libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION}-1; fi
    
WORKDIR  /drivers

ARG PUBLIC_KEY=empty
COPY ${PUBLIC_KEY} kernel/pubkey.x509

# Remove cuda repository to avoid GPG errors
# clean cache
# Add NGC DL license from the CUDA image
RUN rm -f /etc/yum.repos.d/cuda* && dnf clean all && \
    mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

ENTRYPOINT ["nvidia-driver", "init"]
