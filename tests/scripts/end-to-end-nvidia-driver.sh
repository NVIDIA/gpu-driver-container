#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh
source "${SCRIPT_DIR}"/checks.sh

driver_pod_name() {
    local node=${1:-}
    local field_selector=()
    if [[ -n "${node}" ]]; then
        field_selector=(--field-selector "spec.nodeName=${node}")
    fi
    kubectl get pods -n "${TEST_NAMESPACE}" -l app=nvidia-driver-daemonset \
        "${field_selector[@]}" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

wait_for_driver_pod_on_node() {
    local node=$1 pod=
    for _ in $(seq 1 60); do
        pod=$(driver_pod_name "${node}")
        if [[ -n "${pod}" ]]; then
            kubectl wait -n "${TEST_NAMESPACE}" --for=condition=Ready \
                "pod/${pod}" --timeout "${DAEMON_POD_STATUS_TIME_OUT}"
            return $?
        fi
        sleep 2
    done
    echo "Timed out waiting for replacement driver pod on ${node}" >&2
    return 1
}

force_restart_driver_pod() {
    local pod=$1 node=$2
    kubectl delete pod -n "${TEST_NAMESPACE}" "${pod}" --grace-period=0 --force --wait=true
    wait_for_driver_pod_on_node "${node}"
}

verify_module_tree_cache_rdma() {
    local pod node containers

    pod=$(driver_pod_name) || return 1
    node=$(kubectl get pod -n "${TEST_NAMESPACE}" "${pod}" \
        -o jsonpath='{.spec.nodeName}') || return 1
    containers=$(kubectl get pod -n "${TEST_NAMESPACE}" "${pod}" \
        -o jsonpath='{.spec.containers[*].name}') || return 1
    if [[ " ${containers} " != *" nvidia-peermem-ctr "* ]]; then
        echo "Skipping module-tree cache RDMA test: nvidia-peermem-ctr is not deployed"
        return 0
    fi

    echo "Verifying module-tree cache restoration after a forced driver-pod restart"
    force_restart_driver_pod "${pod}" "${node}" || return 1
    pod=$(driver_pod_name "${node}") || return 1
    kubectl logs -n "${TEST_NAMESPACE}" "${pod}" -c nvidia-driver-ctr |
        grep -q 'module-tree-cache operation=restore result=hit' || return 1
    kubectl exec -n "${TEST_NAMESPACE}" "${pod}" -c nvidia-driver-ctr -- \
        chroot /run/nvidia/driver modinfo nvidia-peermem || return 1

    echo "Unloading nvidia-peermem and verifying that the restored tree can reload it"
    kubectl exec -n "${TEST_NAMESPACE}" "${pod}" -c nvidia-driver-ctr -- \
        rmmod nvidia_peermem || return 1
    force_restart_driver_pod "${pod}" "${node}" || return 1
    pod=$(driver_pod_name "${node}") || return 1
    kubectl exec -n "${TEST_NAMESPACE}" "${pod}" -c nvidia-driver-ctr -- \
        test -f /sys/module/nvidia_peermem/refcnt || return 1
    kubectl logs -n "${TEST_NAMESPACE}" "${pod}" -c nvidia-peermem-ctr |
        grep -q 'successfully loaded nvidia-peermem module' || return 1
}

echo ""
echo ""
echo "--------------Installing the GPU Operator--------------"

"${SCRIPT_DIR}"/install-operator.sh

"${SCRIPT_DIR}"/verify-operator.sh

if ! verify_module_tree_cache_rdma; then
    echo "Module-tree cache RDMA verification failed"
    "${SCRIPT_DIR}"/uninstall-operator.sh "${TEST_NAMESPACE}" "gpu-operator"
    exit 1
fi

echo "--------------Verification completed for GPU Operator, uninstalling the GPU operator--------------"

"${SCRIPT_DIR}"/uninstall-operator.sh "${TEST_NAMESPACE}" "gpu-operator"

echo "--------------Verification completed for GPU Operator--------------"
