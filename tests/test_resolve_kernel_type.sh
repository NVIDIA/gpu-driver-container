#!/bin/bash
set -u
set -e

REPO_ROOT=$(cd $(dirname $0)/.. && pwd)
DRIVER_SCRIPT=$REPO_ROOT/ubuntu24.04/nvidia-driver

if [[ ! -f $DRIVER_SCRIPT ]]; then
    echo 'FAIL: driver script not found: '$DRIVER_SCRIPT >&2
    exit 1
fi

mkdir -p fakebin
cat > fakebin/nvidia-installer <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x fakebin/nvidia-installer

tmp=$(mktemp)
cleanup() { rm -f $tmp; }
trap cleanup EXIT

{
    echo 'set -eu'
    sed -n '/^_resolve_kernel_type_from_driver_branch()/,/^}/p' $DRIVER_SCRIPT
    sed -n '/^_resolve_kernel_type()/,/^}/p' $DRIVER_SCRIPT
    echo 'KERNEL_MODULE_TYPE=auto'
    echo 'DRIVER_BRANCH=560'
    echo '_resolve_kernel_type || exit 1'
    echo 'echo KERNEL_TYPE=$KERNEL_TYPE'
} > $tmp

PATH=$PWD/fakebin:$PATH bash $tmp >out.txt 2>&1
rc=$?

if [[ $rc -ne 0 ]] || ! grep -q KERNEL_TYPE=kernel-open out.txt; then
    echo 'FAIL: _resolve_kernel_type did not fall back to branch-based kernel type (rc='$rc')' >&2
    cat out.txt >&2
    exit 1
