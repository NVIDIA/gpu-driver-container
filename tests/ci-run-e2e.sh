#!/bin/bash

set -xe

if [[ $# -ne 4 ]]; then
	echo "TARGET_DRIVER_VERSION GPU_PRODUCT_NAME  TEST_CASE SYSTEM_RESTART are required"
	exit 1
fi

export TARGET_DRIVER_VERSION=${1}
export GPU_PRODUCT_NAME=${2}
export TEST_CASE=${3}
export SYSTEM_RESTART=${4}

TEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

${TEST_DIR}/local.sh 
