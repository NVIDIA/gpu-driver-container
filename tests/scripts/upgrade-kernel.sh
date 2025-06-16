#! /bin/bash
# This test case runs the operator installation / test case with the default options.

if [[ $# -ne 1 ]]; then
	echo "Error: $0 must be called with kernel_version"
	exit 1
fi

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../scripts && pwd )"
source "${SCRIPTS_DIR}"/.definitions.sh

# export kernel version and Run an end-to-end test cycle
export KERNEL_VERSION="$1"

echo "Running kernel upgrade helper with kernel version: ${KERNEL_VERSION}"
"${SCRIPTS_DIR}"/kernel-upgrade-helper.sh
