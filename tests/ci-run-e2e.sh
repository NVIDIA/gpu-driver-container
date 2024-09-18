#!/bin/bash

set -xe

if [[ $# -lt 2 ]]; then
	echo "TEST_CASE TEST_CASE_ARGS are required"
	exit 1
fi

TEST_DIR="$(pwd)/tests"

${TEST_DIR}/local.sh "$@"
