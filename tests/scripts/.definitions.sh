#!/bin/bash
set -e

[[ -z "${DEBUG}" ]] || set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"
PROJECT_DIR="$( cd "${TEST_DIR}/.." && pwd )"
CASES_DIR="$( cd "${TEST_DIR}/cases" && pwd )"

# Set default values if not defined
: ${HELM:="helm"}
: ${PROJECT:="$(basename "${PROJECT_DIR}")"}
 
: ${TEST_NAMESPACE:="test-operator"}

: ${HELM_NVIDIA_REPO:="https://helm.ngc.nvidia.com/nvidia"}

: ${DAEMON_POD_STATUS_TIME_OUT:="15m"}
: ${POD_STATUS_TIME_OUT:="2m"}

: ${LOG_DIR:="/tmp/logs"}

: ${SYSTEM_ONLINE_CHECK_TIMEOUT:="900"}

: ${BASE_TARGET:="jammy"}
