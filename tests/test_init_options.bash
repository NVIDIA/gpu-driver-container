#!/bin/bash
# Regression test: init getopt must accept the options the parser consumes.
set -euo pipefail

driver="$(cd "$(dirname "$0")" && pwd)/../ubuntu26.04/nvidia-driver"
[ -f "$driver" ] || { echo "driver script not found"; exit 1; }

grep -F -q -- '-o am:k:t:' "$driver" || {
    echo 'FAIL: init getopt short options do not include -k/-t'
    exit 1
}
grep -F -q -- '-l accept-license,max-threads:,kernel:,tag:' "$driver" || {
    echo 'FAIL: init getopt long options do not include --kernel/--tag'
    exit 1
}
grep -F -q -- '[-k | --kernel KERNEL_VERSION]' "$driver" || {
    echo 'FAIL: usage does not document --kernel'
    exit 1
}
grep -F -q -- '[-t | --tag PACKAGE_TAG]' "$driver" || {
    echo 'FAIL: usage does not document --tag'
    exit 1
}
if grep -F -A3 'probe_nvidia_peermem) options="" ;;' "$driver" | grep -F -q 'if [ $? -ne 0 ]; then'; then
    echo 'FAIL: post-getopt error check still relies on $? under set -e'
    exit 1
fi

