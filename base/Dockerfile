# Ubuntu 22.04
FROM nvcr.io/nvidia/cuda:12.6.1-base-ubuntu22.04 as jammy

SHELL ["/bin/bash", "-c"]

ARG DRIVER_BRANCH
ARG KERNEL_FLAVOR
ENV DRIVER_BRANCH=${DRIVER_BRANCH}
ENV KERNEL_FLAVOR=${KERNEL_FLAVOR}

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ENV NVIDIA_VISIBLE_DEVICES=void

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils git curl && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu jammy-updates main restricted" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu jammy-security main restricted" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

COPY generate-ci-config /usr/local/bin/generate-ci-config

RUN chmod +x /usr/local/bin/generate-ci-config && \
    generate-ci-config

ENTRYPOINT ["/usr/bin/sleep","1000"]

# Ubuntu 20.04
FROM nvcr.io/nvidia/cuda:12.6.1-base-ubuntu20.04 as focal

SHELL ["/bin/bash", "-c"]

ARG DRIVER_BRANCH
ARG KERNEL_FLAVOR
ENV DRIVER_BRANCH=${DRIVER_BRANCH}
ENV KERNEL_FLAVOR=${KERNEL_FLAVOR}

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/apt/sources.list.d/cuda*

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ENV NVIDIA_VISIBLE_DEVICES=void

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils curl git && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal-security main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu focal-updates main restricted" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://us.archive.ubuntu.com/ubuntu focal-security main restricted" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

COPY generate-ci-config /usr/local/bin/generate-ci-config

RUN chmod +x /usr/local/bin/generate-ci-config 

ENTRYPOINT ["/usr/bin/sleep","1000"]
