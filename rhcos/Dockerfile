# VGPU layer
ARG CUDA_VERSION
FROM nvidia/cuda:${CUDA_VERSION}-base-ubi8 as vgpu

ARG TARGETARCH

SHELL ["/bin/bash", "-c"]

RUN dnf install -y git wget

ENV GOLANG_VERSION=1.20.2

# download appropriate binary based on the target architecture for multi-arch builds
RUN OS_ARCH=${TARGETARCH/x86_64/amd64} && OS_ARCH=${OS_ARCH/aarch64/arm64} && \
    curl https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz \
    | tar -C /usr/local -xz

ENV PATH /usr/local/go/bin:$PATH

WORKDIR /work

RUN git clone https://gitlab.com/nvidia/container-images/driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work
# Driver RHCOS layer
ARG RHEL_VERSION=''
FROM nvidia/cuda:${CUDA_VERSION}-base-ubi8

ARG RHEL_VERSION=''
ARG KERNEL_VERSION=''
ARG DRIVER_BRANCH=''
ARG RT_KERNEL_VERSION=''

USER root

#COPY nvidia-driver /usr/local/bin
#COPY ocp_dtk_entrypoint /usr/local/bin
#COPY common.sh /usr/local/bin
COPY --from=vgpu /work/vgpu-util /usr/local/bin

# Copy the rhsm-register script to enable subscription-manager
# during build time
COPY ./rhsm-register /usr/local/bin/rhsm-register

WORKDIR /drivers

# Kernel packages needed to build drivers / kmod
RUN rm /etc/rhsm-host \
    && /usr/local/bin/rhsm-register \
    && subscription-manager repos \
        --enable rhel-8-for-$(arch)-baseos-rpms \
        --enable rhel-8-for-$(arch)-appstream-rpms \
        --enable=rhel-8-for-$(arch)-baseos-eus-rpms \
    && echo "${RHEL_VERSION}" > /etc/dnf/vars/releasever \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf -y install \
        kernel-core${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-devel${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-headers${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-modules${KERNEL_VERSION:+-}${KERNEL_VERSION} \
        kernel-modules-extra${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    && export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core) \
    && GCC_VERSION=$(cat /lib/modules/${INSTALLED_KERNEL}/config | grep -Eo "Compiler: gcc \(GCC\) ([0-9\.]+)" | grep -Eo "([0-9\.]+)") \
    && if [ $(arch) == "x86_64" ] || [ $(arch) == "aarch64" ]; then ARCH_DEP_PKGS="mokutil"; fi \
    && dnf -y install gcc-${GCC_VERSION} || dnf -y install gcc \
    && dnf -y install elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-stablelists \
        xz diffutils git make openssl keyutils rpm-build pinentry jq ${ARCH_DEP_PKGS} \
    && dnf module install -y nvidia-driver:${DRIVER_BRANCH} \
    && dnf clean all \
    && subscription-manager unregister \
    && useradd -u 1001 -m -s /bin/bash builder

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core); \
    export INSTALLED_RT_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-rt-core); \
    echo "{ \"KERNEL_VERSION\": \"${INSTALLED_KERNEL}\", \"RT_KERNEL_VERSION\": \"${INSTALLED_RT_KERNEL}\", \"RHEL_VERSION\": \"${RHEL_VERSION}\" }" > /etc/driver-toolkit-release.json ; \
    echo -e "KERNEL_VERSION=\"${INSTALLED_KERNEL}\"\nRT_KERNEL_VERSION=\"${INSTALLED_RT_KERNEL}\"\nRHEL_VERSION=\"${RHEL_VERSION}\"" > /etc/driver-toolkit-release.sh

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"
LABEL description="See summary"

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        yum update -y ${CVE_UPDATES} && \
        rm -rf /var/cache/yum/*; \
    fi

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda.repo

ENTRYPOINT ["nvidia-driver", "init"]
