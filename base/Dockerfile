# Ubuntu 26.04
FROM ubuntu:resolute-20260724.1 AS resolute

SHELL ["/bin/bash", "-c"]

ARG DRIVER_BRANCH
ARG KERNEL_FLAVOR
ARG LTS_KERNEL
ENV DRIVER_BRANCH=${DRIVER_BRANCH}
ENV KERNEL_FLAVOR=${KERNEL_FLAVOR}
ENV LTS_KERNEL=${LTS_KERNEL}

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ resolute main restricted universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ resolute-updates main restricted universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ resolute-security main restricted universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu resolute-updates main restricted" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu resolute-security main restricted" >> /etc/apt/sources.list && \
    rm -f /etc/apt/sources.list.d/ubuntu.sources

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ENV NVIDIA_VISIBLE_DEVICES=void

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils git curl && \
    rm -rf /var/lib/apt/lists/*

RUN usermod -o -u 0 -g 0 _apt

COPY generate-ci-config /usr/local/bin/generate-ci-config

RUN chmod +x /usr/local/bin/generate-ci-config && \
    generate-ci-config

ENTRYPOINT ["/usr/bin/sleep","1000"]

# Ubuntu 24.04
FROM ubuntu:noble-20260730.1 AS noble

SHELL ["/bin/bash", "-c"]

ARG DRIVER_BRANCH
ARG KERNEL_FLAVOR
ARG LTS_KERNEL
ENV DRIVER_BRANCH=${DRIVER_BRANCH}
ENV KERNEL_FLAVOR=${KERNEL_FLAVOR}
ENV LTS_KERNEL=${LTS_KERNEL}

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ENV NVIDIA_VISIBLE_DEVICES=void

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils git curl && \
    rm -rf /var/lib/apt/lists/*

RUN ARCH=$(dpkg --print-architecture) && \
    # kernel version is the same for amd64 and arm64, so base image is always built for amd64 ( non-nvidia-64k)
    # for nvidia-64k is arm64-only, so its base image must be built for arm64
    if [ "$ARCH" = "arm64" ]; then \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ noble main universe" > /etc/apt/sources.list && \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ noble-updates main universe" >> /etc/apt/sources.list && \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ noble-security main universe" >> /etc/apt/sources.list; \
    else \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble main universe" > /etc/apt/sources.list && \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble-updates main universe" >> /etc/apt/sources.list && \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble-security main universe" >> /etc/apt/sources.list && \
      echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu noble-updates main restricted" >> /etc/apt/sources.list && \
      echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu noble-security main restricted" >> /etc/apt/sources.list; \
    fi && \
    usermod -o -u 0 -g 0 _apt

COPY generate-ci-config /usr/local/bin/generate-ci-config

RUN chmod +x /usr/local/bin/generate-ci-config && \
    generate-ci-config

ENTRYPOINT ["/usr/bin/sleep","1000"]

# Ubuntu 22.04
FROM ubuntu:jammy-20260731.1 AS jammy

SHELL ["/bin/bash", "-c"]

ARG DRIVER_BRANCH
ARG KERNEL_FLAVOR
ARG LTS_KERNEL
ENV DRIVER_BRANCH=${DRIVER_BRANCH}
ENV KERNEL_FLAVOR=${KERNEL_FLAVOR}
ENV LTS_KERNEL=${LTS_KERNEL}

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ENV NVIDIA_VISIBLE_DEVICES=void

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils git curl && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

COPY generate-ci-config /usr/local/bin/generate-ci-config

RUN chmod +x /usr/local/bin/generate-ci-config && \
    generate-ci-config

ENTRYPOINT ["/usr/bin/sleep","1000"]
