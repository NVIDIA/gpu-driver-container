#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

echo ""
echo ""
echo "--------------Installing the GPU Operator--------------"

${SCRIPT_DIR}/install-operator.sh

"${SCRIPT_DIR}"/verify-operator.sh

echo "--------------Verification completed for GPU Operator, uninstalling the operator--------------"

${SCRIPT_DIR}/uninstall-operator.sh ${TEST_NAMESPACE} "gpu-operator"

echo "--------------Verification completed for GPU Operator--------------"
