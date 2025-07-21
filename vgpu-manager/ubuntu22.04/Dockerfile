FROM nvcr.io/nvidia/cuda:12.9.1-base-ubuntu22.04

ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ARG DRIVER_ARCH=x86_64
ENV DRIVER_ARCH=$DRIVER_ARCH

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

# Install the gcc-12 package in Ubuntu 22.04 as Kernels with versions 5.19.x and 6.5.x need gcc 12.3.0 for compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc-12 g++-12 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12 && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main universe" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

RUN mkdir -p /driver
WORKDIR /driver
ADD NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run .
RUN chmod +x NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run

COPY nvidia-driver /usr/local/bin

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get upgrade -y ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

ENTRYPOINT ["nvidia-driver", "init"]
