#!/bin/bash

set -xe

if [[ $# -ne 4 ]]; then
	echo "TEST_CASE TARGET_DRIVER_VERSION SSH_RETRY DOCKER_GITHUB_TOKEN are required"
	exit 1
fi

export TEST_CASE=${1}
export TARGET_DRIVER_VERSION=${2}
export SSH_RETRY=${3}
export DOCKER_GITHUB_TOKEN=${4}

TEST_DIR="$(pwd)/tests"

${TEST_DIR}/local.sh
