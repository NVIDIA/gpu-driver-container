# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Utility functions & logging

die() {
  echo -e "$0 \\033[0;41;30m[🛑] $*\\033[0m" >&2
}

warn() {
  echo -e "\\033[0;43;30m[⚠️] $*\\033[0m" >&2
}

log() {
  echo -e "\\033[1;32m[+] $*\\033[0m" >&2
}

# Sanity checks

if [ -z "$SSH_PRIVATE_KEY" ]; then
  die "SSH private key must be specified with environment variable SSH_PRIVATE_KEY"
fi

# Setup SSH access

eval "$(ssh-agent -s)"
echo "${SSH_PRIVATE_KEY}" | ssh-add - &> /dev/null
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
ssh-add -L > "${HOME}/.ssh/id_rsa.pub"

# Run CI & Terraform

cd ./ci
terraform init -input=false
CI_COMMIT_TAG="$(git describe --abbrev=0 --tags)"
export CI_COMMIT_TAG
export FORCE=true
export REGISTRY=${IMAGE}
export DRIVER_VERSION=${VERSION}
./run.sh
