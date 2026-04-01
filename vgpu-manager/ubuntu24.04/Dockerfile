FROM nvcr.io/nvidia/cuda:13.2.0-base-ubuntu24.04

ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ARG DRIVER_ARCH=x86_64
ENV DRIVER_ARCH=$DRIVER_ARCH
ARG GIT_COMMIT=""

# Remove cuda repository to avoid GPG errors
RUN rm /etc/apt/sources.list.d/cuda*.list

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        file \
        kmod \
        pciutils && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble-security main universe" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

RUN mkdir -p /driver
WORKDIR /driver
ADD NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run .
RUN chmod +x NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run

COPY nvidia-driver /usr/local/bin
RUN chmod +x /usr/local/bin/nvidia-driver

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get --only-upgrade -y install ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

LABEL io.k8s.display-name="NVIDIA vGPU Manager Container"
LABEL name="NVIDIA vGPU Manager Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL vcs-ref="${GIT_COMMIT}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA vGPU Manager (host driver) through containers"
LABEL description="See summary"

ENTRYPOINT ["nvidia-driver", "init"]
