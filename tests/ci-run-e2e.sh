#!/bin/bash

set -xe

if [[ $# -ne 2 ]]; then
	echo "TEST_CASE TARGET_DRIVER_VERSION are required"
	exit 1
fi

export TEST_CASE=${1}
export TARGET_DRIVER_VERSION=${2}


TEST_DIR="$(pwd)/tests"

${TEST_DIR}/local.sh
