#!/bin/bash
set -u
set -e

REPO_ROOT=$(cd $(dirname $0)/.. && pwd)
DRIVER_SCRIPT=$REPO_ROOT/ubuntu24.04/nvidia-driver

if [[ ! -f $DRIVER_SCRIPT ]]; then
    echo 'FAIL: driver script not found: '$DRIVER_SCRIPT >&2
    exit 1
fi

tmp=$(mktemp)
cleanup() { rm -f $tmp; }
trap cleanup EXIT

{
    echo 'usage() { echo USAGE; exit 1; }'
    echo 'init() { echo INIT_OK KERNEL_VERSION=$KERNEL_VERSION PACKAGE_TAG=$PACKAGE_TAG ACCEPT_LICENSE=$ACCEPT_LICENSE MAX_THREADS=$MAX_THREADS; }'
    sed -n '/^if \[ \$# -eq 0 \]/,/^\$command$/p' $DRIVER_SCRIPT
} > $tmp

if ! out=$(bash $tmp init -k 6.8.0-generic -t builtin -a -m 4); then
    echo 'FAIL: option parsing script exited non-zero (getopt likely rejected -k/-t)' >&2
    exit 1
fi

expected='INIT_OK KERNEL_VERSION=6.8.0-generic PACKAGE_TAG=builtin ACCEPT_LICENSE=yes MAX_THREADS=4'
if [[ $out != $expected ]]; then
    echo 'FAIL: expected '$expected', got '$out'' >&2
    exit 1
fi
