#!/bin/bash
set -e

driver_script="ubuntu26.04/nvidia-driver"

awk '/^eval set --/,/^done/' "$driver_script" > /tmp/option_parser.txt

if grep -q 'for opt in \${options}' /tmp/option_parser.txt; then
    echo "FAIL: option parser iterates over the raw getopt string" >&2
    exit 1
fi

if ! grep -q 'while true; do' /tmp/option_parser.txt; then
    echo "FAIL: option parser does not use a positional-parameter loop" >&2
    exit 1
fi
