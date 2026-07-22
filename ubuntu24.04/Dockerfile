ARG BASE_IMAGE=ubuntu:noble-20260730.1

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG GOLANG_VERSION

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE

# Args needed when using a local driver
ARG DRIVER_VERSION
ARG LOCAL_DRIVER=false

SHELL ["/bin/bash", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        git  \
        wget && \
    rm -rf /var/lib/apt/lists/*



# download appropriate binary based on the target architecture for multi-arch builds
RUN OS_ARCH=${TARGETARCH/x86_64/amd64} && OS_ARCH=${OS_ARCH/aarch64/arm64} && \
    wget -nv -O - https://go.dev/dl/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz \
    | tar -C /usr/local -xz

ENV PATH=/usr/local/go/bin:$PATH

WORKDIR /work

RUN if [ "$DRIVER_TYPE" = "vgpu" ]; then \
    git clone https://github.com/NVIDIA/gpu-driver-container driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work; fi

ADD drivers local-driver/

RUN mkdir -p local-repo && \
    if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$LOCAL_DRIVER" == "false" ]; then \
        rm -f local-driver/*; \
    elif [ "$TARGETARCH" == "amd64" ]; then \
        chmod +x local-driver/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run && \
        rm -f local-driver/NVIDIA-Linux-aarch64-${DRIVER_VERSION}.run && \
        { mv local-driver/nvidia-driver-local-repo-*_amd64.deb local-repo/ 2>/dev/null || true; } && \
        rm -f local-driver/nvidia-driver-local-repo-*.deb; \
    else \
        chmod +x local-driver/NVIDIA-Linux-aarch64-${DRIVER_VERSION}.run && \
        rm -f local-driver/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run && \
        { mv local-driver/nvidia-driver-local-repo-*_arm64.deb local-repo/ 2>/dev/null || true; } && \
        rm -f local-driver/nvidia-driver-local-repo-*.deb; fi

FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_VERSION
ARG GIT_COMMIT
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

# Args needed when using a local driver
ARG LOCAL_DRIVER=false

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN echo "TARGETARCH=$TARGETARCH"

ADD install.sh /tmp

RUN usermod -o -u 0 -g 0 _apt && \
    /tmp/install.sh depinstall && /tmp/install.sh setup_cuda_repo

COPY nvidia-driver /usr/local/bin

COPY --from=build /work/vgpu-util* /usr/local/bin

COPY --from=build /work/local-driver drivers/

# Fetch the installer, fabricmanager and libnvidia-nscq automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$LOCAL_DRIVER" == "false" ]; then \
    cd drivers && \
    /tmp/install.sh download_installer; fi

# Bind-mount the local driver repo package from the build stage so the
# ~500MB repo deb never persists in an image layer
RUN --mount=type=bind,from=build,source=/work/local-repo,target=/tmp/local-repo \
    /tmp/install.sh extra_pkgs_install

WORKDIR  /drivers

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get --only-upgrade -y install ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL vcs-ref="${GIT_COMMIT}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"
LABEL description="See summary"

ENTRYPOINT ["nvidia-driver", "init"]
