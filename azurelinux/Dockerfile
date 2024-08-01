ARG AZURE_LINUX_VERSION=''
FROM mcr.microsoft.com/azurelinux/base/core:${AZURE_LINUX_VERSION}

ARG AZURE_LINUX_VERSION
ARG DRIVER_VERSION=''
ENV DRIVER_VERSION=$DRIVER_VERSION
ARG KERNEL_VERSION=''

USER root

COPY nvidia-driver /usr/local/bin

RUN tdnf -y install util-linux ca-certificates

RUN curl -fsSL -o /etc/yum.repos.d/mariner-nvidia.repo \
     https://raw.githubusercontent.com/microsoft/azurelinux/${AZURE_LINUX_VERSION}/toolkit/docs/nvidia/mariner-nvidia.repo

# Create a location to store the pre-downloaded RPMs for installation during container runtime
RUN mkdir -p /opt/nvidia
RUN tdnf -y --downloadonly --downloaddir=/opt/nvidia install cuda-${DRIVER_VERSION}-${KERNEL_VERSION} \
        nvidia-fabric-manager-${DRIVER_VERSION} libnvidia-nscq-${DRIVER_VERSION}

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"

ENTRYPOINT ["nvidia-driver", "init"]
