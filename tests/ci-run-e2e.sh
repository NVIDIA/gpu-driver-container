#!/bin/bash

set -xe

if [[ $# -ne 4 ]]; then
	echo "TARGET_DRIVER_VERSION GPU_PRODUCT_NAME  TEST_CASE SYSTEM_RESTART are required"
	exit 1
fi

echo "SHIVA $1 $2 $3 $4"


export TARGET_DRIVER_VERSION=${1}
export GPU_PRODUCT_NAME=${2}
export TEST_CASE=${3}
export SYSTEM_RESTART=${4}

echo "SHIVA ==== ${TARGET_DRIVER_VERSION} ${GPU_PRODUCT_NAME} ${TEST_CASE} ${SYSTEM_RESTART} "

TEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "SHIVA ======= ${TARGET_DRIVER_VERSION} ${GPU_PRODUCT_NAME} ${TEST_CASE} ${SYSTEM_RESTART} "
${TEST_DIR}/local.sh 
