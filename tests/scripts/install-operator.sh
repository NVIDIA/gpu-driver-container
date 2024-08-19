#!/bin/bash

if [[ "${SKIP_INSTALL}" == "true" ]]; then
    echo "Skipping install: SKIP_INSTALL=${SKIP_INSTALL}"
    exit 0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh

OPERATOR_OPTIONS="${OPERATOR_OPTIONS} --set driver.repository=${PRIVATE_REGISTRY}/nvidia --set driver.version=${TARGET_DRIVER_VERSION}"

# add helm driver repo 
helm repo add nvidia ${HELM_NVIDIA_REPO} && helm repo update

# Create the test namespace
kubectl create namespace "${TEST_NAMESPACE}"

# Run the helm install command
echo "OPERATOR_OPTIONS: $OPERATOR_OPTIONS"
${HELM} install gpu-operator  nvidia/gpu-operator \
	-n "${TEST_NAMESPACE}" \
	${OPERATOR_OPTIONS} \
		--wait
