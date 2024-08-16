#!/bin/bash

if [[ "${SKIP_VERIFY}" == "true" ]]; then
    echo "Skipping verify: SKIP_VERIFY=${SKIP_VERIFY}"
    exit 0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh

# Import the check definitions
source ${SCRIPT_DIR}/checks.sh

# wait for the nvidia-driver pod to be ready
# If successful, then wait for the validator pod to be ready (this means that the rest of the pods are healthy)
# collect log in case of failure
check_pod_ready "nvidia-driver-daemonset" ${DAEMON_POD_STATUS_TIME_OUT} && \
    check_pod_ready "nvidia-operator-validator" ${POD_STATUS_TIME_OUT}; exit_status=$? 
if [ $exit_status -ne 0 ]; then
    curl -o ${SCRIPT_DIR}/must-gather.sh "https://raw.githubusercontent.com/NVIDIA/gpu-operator/main/hack/must-gather.sh"
    chmod +x ${SCRIPT_DIR}/must-gather.sh
    ARTIFACT_DIR="${LOG_DIR}" ${SCRIPT_DIR}/must-gather.sh
    ${SCRIPT_DIR}/uninstall-operator.sh ${TEST_NAMESPACE} "gpu-operator"
    exit 1
else
    echo "All gpu-operator pods are ready."
fi
