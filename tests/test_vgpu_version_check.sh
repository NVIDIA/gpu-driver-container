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
cat > fakebin/vgpu-util <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x fakebin/vgpu-util

tmp=$(mktemp)
cleanup() { rm -f $tmp; }
trap cleanup EXIT

{
    echo 'set -eu'
    sed -n '/^_find_vgpu_driver_version()/,/^}/p' $DRIVER_SCRIPT
    echo 'DISABLE_VGPU_VERSION_CHECK=false'
    echo '_find_vgpu_driver_version'
} > $tmp

PATH=$PWD/fakebin:$PATH bash $tmp >out.txt 2>&1
rc=$?

if [[ $rc -ne 0 ]]; then
    echo 'FAIL: _find_vgpu_driver_version aborted on vgpu-util failure (rc='$rc')' >&2
    cat out.txt >&2
    exit 1
fi
