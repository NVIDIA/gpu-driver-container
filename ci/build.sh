#!/bin/bash -x
set -e
eval $(ssh-agent -s)
echo "${SSH_PRIVATE_KEY}" | ssh-add - &> /dev/null
mkdir -p ${HOME}/.ssh
chmod 700 ${HOME}/.ssh
ssh-add -L > ${HOME}/.ssh/id_rsa.pub
cd ./ci
terraform init -input=false
export CI_COMMIT_TAG="$(git describe --abbrev=0 --tags)"
export FORCE=true
export REGISTRY=${IMAGE}
export DRIVER_VERSION=${VERSION}
./run.sh
