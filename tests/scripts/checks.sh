#!/bin/bash

check_pod_ready() {
	local pod_label=$1
	local current_time=0
	while :; do
		echo "Checking $pod_label pod"
		kubectl get pods -lapp=$pod_label -n ${TEST_NAMESPACE}

		echo "Checking $pod_label pod readiness"
		is_pod_ready=$(kubectl get pods -lapp=$pod_label -n ${TEST_NAMESPACE} -ojsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null || echo "terminated")

		if [ "${is_pod_ready}" = "True" ]; then
			# Check if the pod is not in terminating state
			is_pod_terminating=$(kubectl get pods -lapp=$pod_label -n ${TEST_NAMESPACE} -o jsonpath='{.items[0].metadata.deletionGracePeriodSeconds}' 2>/dev/null || echo "terminated")
			if [ "${is_pod_terminating}" != "" ]; then
				echo "pod $pod_label is in terminating state..."
			else
				echo "Pod $pod_label is ready"
				break;
			fi
		fi

		if [[ "${current_time}" -gt $((60 * 45)) ]]; then
			echo "timeout reached"
			exit 1;
		fi

		# Echo useful information on stdout
		kubectl get pods -n ${TEST_NAMESPACE}

		echo "Sleeping 5 seconds"
		current_time=$((${current_time} + 5))
		sleep 5
	done
}
