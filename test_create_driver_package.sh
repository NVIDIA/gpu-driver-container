#!/bin/bash
set -euo pipefail

# Regression test: the _create_driver_package function must list nvidia-uvm.ko
# as a make target because it is signed and packed later in the same function.
func_body=$(sed -n '/^_create_driver_package()/,/^}/p' rhel9/nvidia-driver)
make_line=$(printf '%s\n' "$func_body" | grep -E '^\s+make -s -j .* SYSSRC=')

if [ -z "$make_line" ]; then
    echo "FAIL: could not find the make invocation in _create_driver_package"
    exit 1
fi

if printf '%s\n' "$make_line" | grep -q 'nvidia-uvm.ko'; then
    echo "PASS: _create_driver_package builds nvidia-uvm.ko"
else
    echo "FAIL: _create_driver_package does not build nvidia-uvm.ko"
