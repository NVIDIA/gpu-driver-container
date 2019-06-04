# Build nvidia-container-runtime binary
FROM golang:1.11.2 as build-runtime

WORKDIR /go/src/nvidia-container-runtime
COPY nvidia-container-runtime .
RUN go install -v nvidia-container-runtime

# Build driver image
FROM ubuntu:16.04

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
	bc \
	binutils \
        build-essential \
        ca-certificates \
        curl \
	gnupg2 \
	jq \
        kmod \
        libc6:i386 \
        libelf-dev \
	libssl-dev \
	module-init-tools \
	software-properties-common && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ bionic main" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ bionic-updates main" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ bionic-security main" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

RUN curl -fsSL -o /usr/local/bin/donkey https://github.com/3XX0/donkey/releases/download/v1.1.0/donkey && \
    curl -fsSL -o /usr/local/bin/extract-vmlinux https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux && \
    chmod +x /usr/local/bin/donkey /usr/local/bin/extract-vmlinux

#ARG BASE_URL=http://us.download.nvidia.com/XFree86/Linux-x86_64
ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG DRIVER_VERSION=410.72
ENV DRIVER_VERSION=$DRIVER_VERSION

# Install the userspace components and copy the kernel module sources.
RUN cd /tmp && \
    curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run && \
    sh NVIDIA-Linux-x86_64-$DRIVER_VERSION.run -x && \
    cd NVIDIA-Linux-x86_64-$DRIVER_VERSION* && \
    ./nvidia-installer --silent \
                       --no-kernel-module \
                       --install-compat32-libs \
                       --no-nouveau-check \
                       --no-nvidia-modprobe \
                       --no-rpms \
                       --no-backup \
                       --no-check-for-alternate-installs \
                       --no-libglx-indirect \
                       --no-install-libglvnd \
                       --x-prefix=/tmp/null \
                       --x-module-path=/tmp/null \
                       --x-library-path=/tmp/null \
                       --x-sysconfig-path=/tmp/null \
                       --no-glvnd-egl-client \
                       --no-glvnd-glx-client && \
    mkdir -p /usr/src/nvidia-$DRIVER_VERSION && \
    mv LICENSE mkprecompiled kernel /usr/src/nvidia-$DRIVER_VERSION && \
    sed '9,${/^\(kernel\|LICENSE\)/!d}' .manifest > /usr/src/nvidia-$DRIVER_VERSION/.manifest && \
    rm -rf /tmp/*

# Install and configure nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES void

COPY --from=build-runtime /go/bin/nvidia-container-runtime /usr/bin/nvidia-container-runtime

RUN curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | apt-key add - && \
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && \
    curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | tee /etc/apt/sources.list.d/nvidia-container-runtime.list && \
    apt-get update && \
    apt-get install -y nvidia-container-runtime-hook && \
    cd /usr && ln -s lib/x86_64-linux-gnu lib64 && cd - && \
    sed -i 's/^#root/root/; s;@/sbin/ldconfig.real;@/run/nvidia/driver/sbin/ldconfig.real;' /etc/nvidia-container-runtime/config.toml

COPY nvidia-driver /usr/local/bin

WORKDIR /usr/src/nvidia-$DRIVER_VERSION

ARG PUBLIC_KEY=empty
COPY ${PUBLIC_KEY} kernel/pubkey.x509

ENTRYPOINT ["nvidia-driver"]
