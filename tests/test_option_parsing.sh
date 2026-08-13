#!/bin/bash
set -e
driver_script="ubuntu26.04/nvidia-driver"
getopt_line=$(grep -E 'init\).*getopt' "$driver_script")
if ! grep -q 'kernel:' <<<"$getopt_line"; then
    echo "FAIL: --kernel not supported by getopt" >&2
    exit 1
fi
if ! grep -q 'tag:' <<<"$getopt_line"; then
    echo "FAIL: --tag not supported by getopt" >&2
    exit 1
fi
