#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

echo ""
echo ""
echo "--------------Installing the GPU Operator with usePrecompiled Enabled--------------"
echo "--------------SYSTEM_RESTART=${SYSTEM_RESTART}---------------------------------------------------------------------"
# Install the operator with usePrecompiled mode set to true
OPERATOR_OPTIONS="--set driver.usePrecompiled=true" ${SCRIPT_DIR}/install-operator.sh

if [[ "${SYSTEM_RESTART}" == "true" ]]; then
    echo "Restart aws System "
    sudo reboot
    return 0
fi
echo "--------------SHIVA1K--------------"
"${SCRIPT_DIR}"/verify-operator.sh
echo "--------------SHIVA2--------------"
"${SCRIPT_DIR}"/verify-operand-restarts.sh
echo "--------------SHIVA3--------------"

# Install a workload and verify that this works as expected
"${SCRIPT_DIR}"/install-workload.sh
echo "--------------SHIVA4--------------"
"${SCRIPT_DIR}"/verify-workload.sh
echo "--------------SHIVA5--------------"
echo ""
echo ""
echo "----------------------------Updating the NvidiaDriverCR----------------------------"
echo "-----------------------------------------------------------------------------------"
# Test updates of the NvidiaDriver custom resource
"${SCRIPT_DIR}"/update-nvidiadriver.sh

echo ""
echo ""
echo "--------------------------------------Teardown--------------------------------------"
echo "------------------------------------------------------------------------------------"
# Uninstall the workload and operator
"${SCRIPT_DIR}"/uninstall-workload.sh
"${SCRIPT_DIR}"/uninstall-operator.sh
