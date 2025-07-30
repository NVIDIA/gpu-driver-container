# SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

#!/usr/env bash

function remote() {
    ${SCRIPT_DIR}/remote.sh "cd ${PROJECT} && "$@""
}

function remote_retry() {
    ${SCRIPT_DIR}/remote_retry.sh
}
