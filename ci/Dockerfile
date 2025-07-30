# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

FROM ubuntu:16.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       test"

RUN apt-get update && apt-get install -y --no-install-recommends \
        docker-ce \
        git \
        jq \
        openssh-client \
        python-pip \
        python-setuptools \
        unzip \
        yum \
        yum-utils \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --upgrade pip

ENV TF_VERSION=0.12.18
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip -o terraform.zip \
  && unzip terraform.zip \
  && mv terraform /usr/local/bin/terraform \
  && rm terraform.zip


COPY centos/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo

CMD ["/bin/bash"]
