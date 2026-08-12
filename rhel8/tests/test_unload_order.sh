#!/bin/bash
set -eu

script_dir=$(dirname "$(readlink -f \"$0\")")
driver_file=\"$script_dir/../nvidia-driver\"

peermem_line=$(grep -n 'rmmod_args+=(\"nvidia-peermem\")' \"$driver_file\" | head -n1 | cut -d: -f1 || true)
nvidia_line=$(grep -n 'rmmod_args+=(\"nvidia\")' \"$driver_file\" | head -n1 | cut -d: -f1 || true)

if [[ -z \"$peermem_line\" ]] || [[ -z \"$nvidia_line\" ]]; then
    echo \"FAIL: could not locate rmmod_args entries\"
    exit 1
fi

if [[ \"$peermem_line\" -gt \"$nvidia_line\" ]]; then
    echo \"FAIL: nvidia-peermem is added after nvidia in rmmod_args\"
    exit 1
fi

echo \"PASS\"
