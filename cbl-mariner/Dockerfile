ARG CBL_MARINER_VERSION=2.0
FROM mcr.microsoft.com/cbl-mariner/base/core:${CBL_MARINER_VERSION}

ARG DRIVER_BRANCH=525
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG DRIVER_VERSION=525.85.12
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG KERNEL_VERSION=5.15.131.1-2.cm2
ENV KERNEL_VERSION=$KERNEL_VERSION

USER root

COPY nvidia-driver /usr/local/bin

RUN MARINER_NVIDIA_GPGKEY_SUM=4097a14dd56c7d9a44ac164945396c3a460346fca94fe89deebec8468f18c8df && \
    curl -fsSL https://packages.microsoft.com/cbl-mariner/${CBL_MARINER_VERSION}/prod/nvidia/x86_64/repodata/repomd.xml.key > /etc/pki/rpm-gpg/RPM-GPG-KEY-MARINER-NVIDIA && \
    echo "$MARINER_NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-MARINER-NVIDIA" | sha256sum -c --strict -
x
RUN curl -fsSl https://packages.microsoft.com/cbl-mariner/${CBL_MARINER_VERSION}/prod/nvidia/x86_64/config.repo > /etc/yum.repos.d/mariner-nvidia.repo && \
    tdnf -y install util-linux tar

# Download the driver and dependent packages and stage for install during runtime
RUN tdnf -y --downloadonly install kernel-${KERNEL_VERSION} \
        $(tdnf repoquery "cuda-${DRIVER_VERSION}" | grep -m1 ${KERNEL_VERSION//-/.})    \
        "nvidia-fabric-manager-${DRIVER_VERSION}" \

# Remove the GPG public key and the mariner repository to avoid GPG errors
RUN rm -f /etc/pki/rpm-gpg/RPM-GPG-KEY-MARINER-NVIDIA && rm -f /etc/yum.repos.d/mariner-nvidia.repo

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"

ENTRYPOINT ["nvidia-driver", "init"]
