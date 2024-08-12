#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

echo ""
echo ""
echo "--------------Installing the GPU Operator--------------"

# Install the operator with usePrecompiled mode set to true
${SCRIPT_DIR}/install-operator.sh

if [[ "${SYSTEM_RESTART}" == "true" ]]; then
    echo "Restart aws System "
    sudo reboot
    return 0
fi

"${SCRIPT_DIR}"/verify-operator.sh
echo "--------------Verification completed for GPU Operator--------------"
