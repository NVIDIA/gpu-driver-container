#!/usr/bin/env bash
# Regression test for _find_vgpu_driver_version error handling.
# The function must not abort under 'set -e' when vgpu-util returns an error.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")/.." && pwd)
driver_script="$script_dir/ubuntu24.04/nvidia-driver"

func=$(awk '/^_find_vgpu_driver_version\(\) \{/,/^}$/' "$driver_script")
if [[ -z "$func" ]]; then
    echo "ERROR: could not extract _find_vgpu_driver_version" >&2
    exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp_script="$tmp/test.sh"

{
    printf '%s\n' "$func"
    cat <<'EOF'

DISABLE_VGPU_VERSION_CHECK=false
NUM_VGPU_DEVICES=0
DRIVER_VERSION=test
DRIVER_TYPE=vgpu

vgpu-util() {
    return 1
}

_find_vgpu_driver_version
EOF
} > "$tmp_script"

if bash -e "$tmp_script" >/dev/null 2>&1; then
    echo "PASS: vgpu-util failure is handled gracefully"
else
    echo "FAIL: vgpu-util failure caused an unexpected abort"
    exit 1
fi
