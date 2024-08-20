#!/bin/bash

check_pod_ready() {
	local pod_label=$1
	local pod_status_time_out=$2
	
	echo "Checking $pod_label pod"
	
	kubectl get pods -lapp=$pod_label -n ${TEST_NAMESPACE}

	echo "Checking $pod_label pod readiness"

	if kubectl wait -n ${TEST_NAMESPACE} --for=condition=Ready pod -l app=$pod_label --timeout ${pod_status_time_out}; then
		return 0	
	else
		# print status of pod
		kubectl get pods -n ${TEST_NAMESPACE}
	fi

	return 1
}
