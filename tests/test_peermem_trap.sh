#!/bin/bash
set -e

driver_script="ubuntu26.04/nvidia-driver"

awk '/^reload_nvidia_peermem\(\)/,/^}/' "$driver_script" > /tmp/reload_func.txt

trap_line=$(grep -n '^[[:space:]]*trap' /tmp/reload_func.txt | head -1 | cut -d: -f1 || true)
sleep_line=$(grep -n '^[[:space:]]*sleep inf' /tmp/reload_func.txt | head -1 | cut -d: -f1 || true)

if [ -z "$trap_line" ] || [ -z "$sleep_line" ]; then
    echo "FAIL: could not locate trap and/or sleep inf lines" >&2
    exit 1
fi

if [ "$trap_line" -gt "$sleep_line" ]; then
    echo "FAIL: trap is installed after the first blocking sleep" >&2
    exit 1
fi

echo "PASS"
