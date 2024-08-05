#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

# Install the operator and ensure that this works as expected
echo ""
echo ""
echo "--------------Installing the GPU Operator------------------------------------------"
echo "-----------------------------------------------------------------------------------"
"${SCRIPT_DIR}"/install-operator.sh
