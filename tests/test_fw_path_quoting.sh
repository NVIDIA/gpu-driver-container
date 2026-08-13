#!/bin/bash
# Regression test: the firmware path occupancy check must quote its command
# substitution so multi-word contents do not break the [[ ]] test.
set -euo pipefail

driver_file="ubuntu22.04/nvidia-driver"

if grep -q '\[\[ ! -z $(grep' "$driver_file"; then
    echo "FAIL: unquoted command substitution in [[ ]] test remains"
    exit 1
fi

