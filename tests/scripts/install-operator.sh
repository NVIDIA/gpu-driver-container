#!/bin/bash

if [[ "${SKIP_INSTALL}" == "true" ]]; then
    echo "Skipping install: SKIP_INSTALL=${SKIP_INSTALL}"
    exit 0
fi

echo "Checking current kernel version..."
CURRENT_KERNEL=$(uname -r)
echo "Current kernel version: $CURRENT_KERNEL"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh

# add helm driver repo
# SHIVA 
echo "SHIVA TOKEN_TARGET ${DOCKER_GITHUB_TOKEN}"
#docker login ${HELM_NVIDIA_REPO} -u x-access-token --password $DOCKER_GITHUB_TOKEN

helm repo add nvidia ${HELM_NVIDIA_REPO} && helm repo update

# Create the test namespace
kubectl create namespace "${TEST_NAMESPACE}"
kubectl create secret docker-registry ngc-secret  --docker-server=${PRIVATE_REGISTRY}/nvidia --docker-username='$oauthtoken' --docker-password=${DOCKER_GITHUB_TOKEN} -n ${TEST_NAMESPACE}
# SHIVA add for precompiled 
# --set driver.usePrecompiled=true 
OPERATOR_OPTIONS="${OPERATOR_OPTIONS} --set driver.repository=${PRIVATE_REGISTRY}/nvidia --set driver.version=${TARGET_DRIVER_VERSION} --set imagePullSecrets=ngc-secret  --set driver.imagePullSecrets={ngc-secret}"

# Run the helm install command
echo "OPERATOR_OPTIONS: $OPERATOR_OPTIONS"
${HELM} install gpu-operator  nvidia/gpu-operator \
	-n "${TEST_NAMESPACE}" \
	${OPERATOR_OPTIONS} \
		--wait
