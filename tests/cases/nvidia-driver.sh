#! /bin/bash
# This test case runs the operator installation / test case with the default options.

if [[ $# -lt 1 ]]; then
	echo "Error: $0 must be called with driver options"
	exit 1
fi

# export gpu-operator options
export TEST_CASE_ARGS="$1"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../scripts && pwd )"
source "${SCRIPTS_DIR}"/.definitions.sh

# Run an end-to-end test cycle
"${SCRIPTS_DIR}"/end-to-end-nvidia-driver.sh
