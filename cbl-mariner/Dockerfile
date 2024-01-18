ARG CBL_MARINER_VERSION=2.0
FROM mcr.microsoft.com/cbl-mariner/base/core:${CBL_MARINER_VERSION}

ARG CBL_MARINER_VERSION
ARG DRIVER_BRANCH=525
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=525.85.12
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG KERNEL_VERSION=5.15.138.1-4.cm2
ENV KERNEL_VERSION=$KERNEL_VERSION

USER root

COPY nvidia-driver /usr/local/bin

RUN tdnf -y install util-linux ca-certificates

RUN curl -fsSL -o /etc/yum.repos.d/mariner-nvidia.repo \
     https://raw.githubusercontent.com/microsoft/CBL-Mariner/${CBL_MARINER_VERSION}/toolkit/docs/nvidia/mariner-nvidia.repo

# Create a location to store the pre-downloaded RPMs for installation during container runtime
RUN mkdir -p /opt/nvidia
RUN tdnf -y --downloadonly --downloaddir=/opt/nvidia install $(tdnf repoquery "cuda-${DRIVER_VERSION}" | grep -m1 ${KERNEL_VERSION//-/.})    \
        "nvidia-fabric-manager-${DRIVER_VERSION}"

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"

ENTRYPOINT ["nvidia-driver", "init"]
