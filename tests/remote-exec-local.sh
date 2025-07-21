# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#! /bin/bash

if [[ $# -ge 1 ]]; then
    REMOTE_EXEC=${1}
    test -n "${REMOTE_EXEC}"
fi
test -f ${PROJECT_DIR}/${REMOTE_EXEC}

export PROJECT="gpu-driver-container"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/scripts && pwd )"
source ${SCRIPT_DIR}/.definitions.sh
source ${SCRIPT_DIR}/.local.sh

# Sync the project folder to the remote
${SCRIPT_DIR}/push.sh

# We trigger the specified script on the remote instance.
remote \
    PROJECT="${PROJECT}" \
        "$@"
