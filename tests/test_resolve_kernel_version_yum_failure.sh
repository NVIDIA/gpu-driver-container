#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp rhel8/nvidia-driver "$tmp/lib.sh"
sed -i '/^usage() {/,$d' "$tmp/lib.sh"
: > "$tmp/common.sh"

export DRIVER_VERSION="550.54.15"
export TARGETARCH="amd64"
export KERNEL_VERSION="4.18.0-513.el8_9.x86_64"
export DRIVER_BRANCH=550

set +e
output=$(
  cd "$tmp"
  . ./lib.sh >/dev/null 2>&1
  yum() { return 1; }
  if ! _resolve_kernel_version 2>&1; then
    echo "HANDLED"
  fi
  echo "MARKER"
)
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "FAIL: _resolve_kernel_version caused an early exit (status=$status)"
  exit 1
fi
if [[ "$output" == *"Could not resolve Linux kernel version"* && "$output" == *"HANDLED"* && "$output" == *"MARKER"* ]]; then
  echo "PASS: _resolve_kernel_version handles yum failure"
else
