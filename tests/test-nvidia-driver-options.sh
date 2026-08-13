#!/usr/bin/env bash
# Regression test for option parsing in ubuntu22.04/nvidia-driver.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DRIVER_SCRIPT="${SCRIPT_DIR}/../ubuntu22.04/nvidia-driver"

# Stubs for the top-level command functions so sourcing the driver script
# does not perform real work. We rename the original definitions below so
# these stubs remain in effect.
init() { _print_vars; }
update() { _print_vars; }
reload_nvidia_peermem() { _print_vars; }
probe_nvidia_peermem() { _print_vars; }
usage() { echo "USAGE"; exit 1; }

_print_vars() {
    printf 'ACCEPT_LICENSE=[%s]\n' "${ACCEPT_LICENSE:-}"
    printf 'MAX_THREADS=[%s]\n' "${MAX_THREADS:-}"
    printf 'KERNEL_VERSION=[%s]\n' "${KERNEL_VERSION:-}"
    printf 'PRIVATE_KEY=[%s]\n' "${PRIVATE_KEY:-}"
    printf 'PACKAGE_TAG=[%s]\n' "${PACKAGE_TAG:-}"
}

export TARGETARCH=amd64
export DRIVER_VERSION=570.00

run() {
    local expected="$1"; shift
    local output
    output=$(
        # Rename the original command/usage function definitions so that
        # our stubs above take effect when the driver script is sourced.
        source <(
            sed -e 's/^init() {/init_old() {/' \
                -e 's/^update() {/update_old() {/' \
                -e 's/^reload_nvidia_peermem() {/reload_nvidia_peermem_old() {/' \
                -e 's/^probe_nvidia_peermem() {/probe_nvidia_peermem_old() {/' \
                -e 's/^usage() {/usage_old() {/' \
                "${DRIVER_SCRIPT}"
        ) "$@" 2>&1
    ) || true
    if [ "$output" != "$expected" ]; then
        echo "FAIL: $*"
        echo "Expected:"
        echo "$expected"
        echo "Got:"
        echo "$output"
        exit 1
    fi
}

run 'ACCEPT_LICENSE=[yes]
MAX_THREADS=[8]
KERNEL_VERSION=[]
PRIVATE_KEY=[]
PACKAGE_TAG=[]' init -a -m 8

run 'ACCEPT_LICENSE=[]
MAX_THREADS=[-a]
KERNEL_VERSION=[]
PRIVATE_KEY=[]
PACKAGE_TAG=[]' init -m '-a'

run 'ACCEPT_LICENSE=[]
MAX_THREADS=[]
