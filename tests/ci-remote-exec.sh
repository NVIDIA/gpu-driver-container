# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#!/bin/bash

set -xe

if [[ $# -lt 1 ]]; then
	echo "Error:$0 must be called with 1(REMOTE_EXEC) or more than 1 args (REMOTE_EXEC, ARGS1 ARGS2  etc)"
	exit 1
fi

TEST_DIR="$(pwd)/tests"

${TEST_DIR}/remote-exec-local.sh "$@"
