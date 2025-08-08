# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#! /bin/bash

if [[ $# -ge 1 ]]; then
    TEST_CASE=${1}
    test -n "${TEST_CASE}"
fi
test -f ${PROJECT_DIR}/${TEST_CASE}

export PROJECT="gpu-driver-container"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/scripts && pwd )"
source ${SCRIPT_DIR}/.definitions.sh
source ${SCRIPT_DIR}/.local.sh

# Sync the project folder to the remote
${SCRIPT_DIR}/push.sh

# We trigger the installation of prerequisites on the remote instance
remote SKIP_PREREQUISITES="${SKIP_PREREQUISITES}" ./tests/scripts/prerequisites.sh

# We trigger the specified test case on the remote instance.
# Note: We need to ensure that the required environment variables
# are forwarded to the remote shell.
remote \
    PROJECT="${PROJECT}" \
        "$@"
