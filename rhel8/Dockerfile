ARG CUDA_VERSION
FROM nvidia/cuda:${CUDA_VERSION}-base-ubi8 as build

ARG TARGETARCH

SHELL ["/bin/bash", "-c"]

RUN dnf install -y git wget

ENV GOLANG_VERSION=1.17

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

FROM nvidia/cuda:${CUDA_VERSION}-base-ubi8

ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH

SHELL ["/bin/bash", "-c"]

#ARG BASE_URL=http://us.download.nvidia.com/XFree86/Linux-x86_64
ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION

# Arg to indicate if driver type is either of passthrough/baremetal or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE
ARG VGPU_LICENSE_SERVER_TYPE=FNE
ENV VGPU_LICENSE_SERVER_TYPE=$VGPU_LICENSE_SERVER_TYPE
# Enable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=false
ENV DISABLE_VGPU_VERSION_CHECK=$DISABLE_VGPU_VERSION_CHECK
# Avoid dependency of container-toolkit for driver container
ENV NVIDIA_VISIBLE_DEVICES=void

ADD install.sh /tmp/

RUN NVIDIA_GPGKEY_SUM=d0664fbbdb8c32356d45de36c5984617217b2d0bef41b93ccecd326ba3b80c87 && \
    OS_ARCH=${TARGETARCH/amd64/x86_64} && OS_ARCH=${OS_ARCH/arm64/sbsa} && \
    curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/rhel8/$OS_ARCH/D42D0685.pub" | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict -

RUN sh /tmp/install.sh depinstall && \
    curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    curl -fsSL -o /usr/local/bin/extract-vmlinux https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux && \
    chmod +x /usr/local/bin/donkey /usr/local/bin/extract-vmlinux && \
    ln -s /sbin/ldconfig /sbin/ldconfig.real

ADD drivers drivers/

# Fetch the installer automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
    cd drivers && \
    DRIVER_ARCH=${TARGETARCH/amd64/x86_64} && DRIVER_ARCH=${DRIVER_ARCH/arm64/aarch64} && \
    curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run && \
    chmod +x  NVIDIA-Linux-$DRIVER_ARCH-$DRIVER_VERSION.run; fi

# Install fabric-manager packages
RUN if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$TARGETARCH" != "arm64" ]; then \
    versionArray=(${DRIVER_VERSION//./ }); \
    DRIVER_BRANCH=${versionArray[0]}; \
    if [ ${versionArray[0]} -ge 470 ] || ([ ${versionArray[0]} == 460 ] && [ ${versionArray[1]} -ge 91 ]); then \
      fmPackage=nvidia-fabric-manager-${DRIVER_VERSION}-1; \
    else \
      fmPackage=nvidia-fabricmanager-${DRIVER_BRANCH}-${DRIVER_VERSION}-1; \
    fi; \
    nscqPackage=libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION}-1; \
    dnf module enable -y nvidia-driver:${DRIVER_BRANCH} && \
    dnf install -y ${fmPackage} ${nscqPackage}; fi

COPY nvidia-driver /usr/local/bin
COPY ocp_dtk_entrypoint /usr/local/bin
COPY common.sh /usr/local/bin

COPY --from=build /work/vgpu-util /usr/local/bin

WORKDIR /drivers

ARG PUBLIC_KEY=empty
COPY ${PUBLIC_KEY} kernel/pubkey.x509

ARG PRIVATE_KEY
ARG KERNEL_VERSION=latest

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"
LABEL description="See summary"

COPY LICENSE /licenses/LICENSE
COPY DRIVER-LICENSE /licenses/DRIVER-LICENSE

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        yum update -y ${CVE_UPDATES} && \
        rm -rf /var/cache/yum/*; \
    fi

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda.repo

ENTRYPOINT ["nvidia-driver", "init"]
