# Ubuntu 26.04
FROM ubuntu:resolute-20260610 AS resolute

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
FROM ubuntu:26.04 AS noble

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

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ noble-security main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu noble-updates main restricted" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu noble-security main restricted" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

COPY generate-ci-config /usr/local/bin/generate-ci-config

RUN chmod +x /usr/local/bin/generate-ci-config && \
    generate-ci-config

ENTRYPOINT ["/usr/bin/sleep","1000"]

# Ubuntu 22.04
FROM ubuntu:26.04 AS jammy

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
