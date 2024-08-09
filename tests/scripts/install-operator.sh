#!/bin/bash

if [[ "${SKIP_INSTALL}" == "true" ]]; then
    echo "Skipping install: SKIP_INSTALL=${SKIP_INSTALL}"
    exit 0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh

export PATH=/usr/local/nvidia/toolkit/:$PATH
export LD_LIBRARY_PATH=/usr/local/nvidia/toolkit/:$LD_LIBRARY_PATH
export NGC_API_KEY="cmY3ZXYyM3RjMnNsZGc2cDFlOGZmY2NpY2s6OTA3MWQ0MmEtNmNiMy00NWMwLTk2ZDUtM2ZhOTdlZWRiMGY1"

kubectl create namespace gpu-operator;
kubectl create secret docker-registry ngc-secret  --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=${NGC_API_KEY} -n gpu-operator

helm install gpu-operator nvidia/gpu-operator   -n gpu-operator   --create-namespace   --set driver.repository=nvcr.io/ea-cnt/nv_only   --set driver.version=550   --set driver.usePrecompiled=true   --set driver.useOpenKernelModules=true   --set imagePullSecrets=ngc-secret   --set driver.imagePullPolicy=Always --set driver.imagePullSecrets={ngc-secret}