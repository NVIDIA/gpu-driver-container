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

: ${PRIVATE_REGISTRY:="ghcr.io"}

: ${HELM_NVIDIA_REPO:="https://helm.ngc.nvidia.com/nvidia"}

: ${TARGET_DRIVER_VERSION:="550.90.07"}
