#!/bin/bash
set -eu

# Regression test: command substitution followed by a $? check is unreachable
# under 'set -e'. The fixed code uses 'if ! cmd=$(...); then ... fi' instead.

fail=0
if grep -A1 -E '^[[:space:]]*kernel_module_type=\$\(' rhel10/nvidia-driver | grep -q '^[[:space:]]*if \[ \$\? -ne 0 \]'; then
    echo "FAIL: nvidia-installer result is still checked with unreachable $?"
    fail=1
fi
if grep -A1 -E '^[[:space:]]*(count|version)=\$\(' rhel10/nvidia-driver | grep -q '^[[:space:]]*if \[ \$\? -ne 0 \]'; then
    echo "FAIL: vgpu-util result is still checked with unreachable $?"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

