ARG CUDA_VERSION=''
FROM nvidia/cuda:${CUDA_VERSION}-base-ubi8

ARG KERNEL_VERSION=''
ENV KERNEL_VERSION=$KERNEL_VERSION

ARG RHEL_VERSION=''
ENV RHEL_VERSION=$RHEL_VERSION

ARG DRIVER_BRANCH=''
ENV DRIVER_BRANCH=$DRIVER_BRANCH

ARG DRIVER_VERSION=''
ENV DRIVER_VERSION=$DRIVER_VERSION

ARG TARGET_ARCH
ENV TARGET_ARCH=$TARGET_ARCH

# Disable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=true
ENV DISABLE_VGPU_VERSION_CHECK=$DISABLE_VGPU_VERSION_CHECK

USER root

COPY --chmod=744 nvidia-driver /usr/local/bin
COPY --chmod=744 common.sh /usr/local/bin

# Copy the rhsm-register script to enable subscription-manager
# during build time
COPY --chmod=744 ./rhsm-register /usr/local/bin/rhsm-register

WORKDIR /drivers

# Kernel packages needed to build drivers / kmod
RUN rm /etc/rhsm-host \
    && /usr/local/bin/rhsm-register \
    && echo "${RHEL_VERSION}" > /etc/dnf/vars/releasever \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf -y install kmod binutils ipmitool

# Prevent modprobe from giving a WARNING about missing files
RUN rm -rf /lib/modules/${KERNEL_VERSION}.${TARGET_ARCH} \
    && mkdir -p /lib/modules/${KERNEL_VERSION}.${TARGET_ARCH}/proc \
    && touch /lib/modules/${KERNEL_VERSION}.${TARGET_ARCH}/modules.order \
    && touch /lib/modules/${KERNEL_VERSION}.${TARGET_ARCH}/modules.builtin

# Install the Driver modules 
RUN dnf module install -y nvidia-driver:${DRIVER_BRANCH} \
    && depmod ${KERNEL_VERSION}.${TARGET_ARCH} \
    && dnf clean all \
    && subscription-manager unregister \
    && useradd -u 1001 -m -s /bin/bash builder

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"
LABEL description="See summary"

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda.repo

ENTRYPOINT ["nvidia-driver", "init"]
