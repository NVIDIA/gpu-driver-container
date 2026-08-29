ARG BASE_IMAGE=ubuntu:resolute-20260724.1

FROM anchore/syft:v1.51.1 AS syft
FROM ghcr.io/jqlang/jq:1.8.2 AS jq

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG GOLANG_VERSION

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE

SHELL ["/bin/bash", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

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

RUN git clone --depth 1 https://github.com/NVIDIA/gpu-driver-container driver && \
    cp driver/scripts/generate-in-image-tpn.sh /work/generate-in-image-tpn.sh && \
    if [ "$DRIVER_TYPE" = "vgpu" ]; then \
        (cd driver/vgpu/src && go build -o /work/vgpu-util); fi

FROM ${BASE_IMAGE} AS runtime

SHELL ["/bin/bash", "-c"]

ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ARG DRIVER_VERSION
ARG GIT_COMMIT
ENV DRIVER_VERSION=$DRIVER_VERSION
ENV DEBIAN_FRONTEND=noninteractive

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE
ARG DRIVER_BRANCH=595
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
    /tmp/install.sh depinstall

# Install the driver payload for passthrough/baremetal types; the vgpu type installs from a
# .run file at container start
RUN /tmp/install.sh driver_pkgs_install

COPY nvidia-driver /usr/local/bin

COPY --from=build /work/vgpu-util* /usr/local/bin

ADD drivers drivers/

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

# Generate third-party notices from the completed runtime filesystem
FROM runtime AS tpn

ARG GOLANG_VERSION

COPY --from=syft /syft /tmp/tpn-tools/syft
COPY --from=jq /jq /tmp/tpn-tools/jq
COPY --from=build /work/generate-in-image-tpn.sh /tmp/generate-in-image-tpn.sh

RUN PATH="/tmp/tpn-tools:${PATH}" \
    SYFT=/tmp/tpn-tools/syft \
    JQ=/tmp/tpn-tools/jq \
    bash /tmp/generate-in-image-tpn.sh /licenses

FROM runtime

COPY --from=tpn /licenses /licenses
