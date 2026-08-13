#!/bin/bash
# Regression test: command-substitution failures must be caught under set -e.
set -euo pipefail

driver="$(cd "$(dirname "$0")" && pwd)/../ubuntu26.04/nvidia-driver"
[ -f "$driver" ] || { echo "driver script not found"; exit 1; }

# The script must still run with set -e for this bug class to matter.
grep -q '^set -eu$' "$driver"

# _find_vgpu_driver_version: count
if grep -F -A1 'count=$(vgpu-util count)' "$driver" | grep -F -q 'if [ $? -ne 0 ]'; then
    echo 'FAIL: count assignment relies on $? under set -e'
    exit 1
fi
grep -F -q 'count=$(vgpu-util count) || rc=$?' "$driver" || {
    echo 'FAIL: count exit status is not captured'
    exit 1
}

# _find_vgpu_driver_version: version
if grep -F -A1 'version=$(vgpu-util match' "$driver" | grep -F -q 'if [ $? -ne 0 ]'; then
    echo 'FAIL: version assignment relies on $? under set -e'
    exit 1
fi
grep -F -q 'version=$(vgpu-util match -i /drivers -c /drivers/vgpuDriverCatalog.yaml) || rc=$?' "$driver" || {
    echo 'FAIL: version exit status is not captured'
    exit 1
}

# _resolve_kernel_type
if grep -F -A1 'kernel_module_type=$(nvidia-installer --print-recommended-kernel-module-type)' "$driver" | grep -F -q 'if [ $? -ne 0 ]'; then
    echo 'FAIL: kernel_module_type assignment relies on $? under set -e'
    exit 1
fi
grep -F -q 'kernel_module_type=$(nvidia-installer --print-recommended-kernel-module-type) || rc=$?' "$driver" || {
    echo 'FAIL: kernel_module_type exit status is not captured'
    exit 1
}

echo 'PASS: command-substitution errors are handled safely under set -e'
