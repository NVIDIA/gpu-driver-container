FROM ubuntu:20.04 as build

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        git && \
    rm -rf /var/lib/apt/lists/*

ENV GOLANG_VERSION 1.15.5
RUN curl -fsSL https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz \
    | tar -C /usr/local -xz
ENV PATH /usr/local/go/bin:$PATH

WORKDIR /work

RUN git clone https://gitlab.com/nvidia/container-images/driver && \
    cd driver/vgpu/src && \
    go build -o vgpu-util && \
    mv vgpu-util /work

FROM nvidia/cuda:11.3.0-base-ubuntu20.04

#ARG BASE_URL=http://us.download.nvidia.com/XFree86/Linux-x86_64
ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ENV DEBIAN_FRONTEND=noninteractive

# Arg to indicate if driver type is either of passthrough(baremetal) or vgpu
ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=$DRIVER_TYPE
ARG DRIVER_BRANCH=460
ENV DRIVER_BRANCH=$DRIVER_BRANCH
ARG VGPU_LICENSE_SERVER_TYPE=FNE
ENV VGPU_LICENSE_SERVER_TYPE=$VGPU_LICENSE_SERVER_TYPE
# Enable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=false
ENV DISABLE_VGPU_VERSION_CHECK=$DISABLE_VGPU_VERSION_CHECK
ENV NVIDIA_VISIBLE_DEVICES=void

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        kmod \
        file \
        libelf-dev \
        libglvnd-dev \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal-security main universe" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

RUN curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    chmod +x /usr/local/bin/donkey

COPY nvidia-driver /usr/local/bin

COPY --from=build /work/vgpu-util /usr/local/bin

ADD drivers drivers/

# Fetch the installer automatically for passthrough/baremetal types
RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
    cd drivers && \
    curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run && \
    chmod +x  NVIDIA-Linux-x86_64-$DRIVER_VERSION.run && \
    apt-get update && \
    apt-get install -y --no-install-recommends nvidia-fabricmanager-${DRIVER_BRANCH}=${DRIVER_VERSION}-1 \
    libnvidia-nscq-${DRIVER_BRANCH}=${DRIVER_VERSION}-1; fi

WORKDIR  /drivers

ARG PUBLIC_KEY=empty
COPY ${PUBLIC_KEY} kernel/pubkey.x509

ENTRYPOINT ["nvidia-driver", "init"]
