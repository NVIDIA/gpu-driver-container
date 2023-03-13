ARG RHEL_VERSION=''
FROM nvidia/cuda:${CUDA_VERSION}-base-ubi8

ARG RHEL_VERSION=''
ARG KERNEL_VERSION=''
ARG DRIVER_BRANCH=''
ARG RT_KERNEL_VERSION=''
# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES

USER root

COPY nvidia-driver /usr/local/bin
COPY common.sh /usr/local/bin

# Copy the rhsm-register script to enable subscription-manager
# during build time
COPY ./rhsm-register /usr/local/bin/rhsm-register

WORKDIR /drivers

# Kernel packages needed to build drivers / kmod
RUN rm /etc/rhsm-host \
    && /usr/local/bin/rhsm-register \
    && echo "${RHEL_VERSION}" > /etc/dnf/vars/releasever \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf -y install kmod binutils \
    && dnf module install -y nvidia-driver:${DRIVER_BRANCH} \
    && if [ -n "${CVE_UPDATES}" ]; then yum update -y ${CVE_UPDATES} fi \
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
