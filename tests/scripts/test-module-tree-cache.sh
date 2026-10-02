#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

FAILURE_COUNT=0
KERNEL_VERSION=test-kernel
DRIVER_VERSION=580.1.2
DRIVER_CONFIG_DIGEST=digest-a
DRIVER_TYPE=passthrough
GPU_DIRECT_RDMA_ENABLED=true
RUN_DIR="${WORK_DIR}/run/nvidia"
MODULE_TREE_ROOTFS="${WORK_DIR}/rootfs"
MODULE_TREE_MODULES_ROOT="${MODULE_TREE_ROOTFS}/lib/modules"
MODULE_TREE_SYS_MODULE_ROOT="${WORK_DIR}/sys/module"
MODULE_TREE_CACHE_DIR="${RUN_DIR}/module-tree-cache"
MODULE_TREE_CACHE_MAX_MB=32
MODULE_TREE_CACHE_MIN_FREE_MB=0
MODULE_TREE_KERNEL_RELEASE="${KERNEL_VERSION}"
FAKE_MODULES_ROOT="${MODULE_TREE_MODULES_ROOT}"
export KERNEL_VERSION DRIVER_VERSION DRIVER_CONFIG_DIGEST DRIVER_TYPE
export GPU_DIRECT_RDMA_ENABLED RUN_DIR MODULE_TREE_ROOTFS MODULE_TREE_MODULES_ROOT
export MODULE_TREE_SYS_MODULE_ROOT MODULE_TREE_CACHE_DIR MODULE_TREE_CACHE_MAX_MB
export MODULE_TREE_CACHE_MIN_FREE_MB MODULE_TREE_KERNEL_RELEASE FAKE_MODULES_ROOT

mkdir -p "${WORK_DIR}/bin" "${RUN_DIR}" "${MODULE_TREE_MODULES_ROOT}/${KERNEL_VERSION}"

cat > "${WORK_DIR}/bin/modprobe" <<'EOF'
#!/usr/bin/env bash
root=/
kernel=
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d) root=$2; shift 2 ;;
        -S) kernel=$2; shift 2 ;;
        --show-depends|-a) shift ;;
        *) shift ;;
    esac
done
if [[ "${root}" == "/" ]]; then
    # kmod emits a double slash when its basedir is explicitly '/'.
    base="//lib/modules/${kernel}"
else
    base="${root%/}/lib/modules/${kernel}"
fi
for module in i2c_core ipmi_msghandler ipmi_devintf nvidia nvidia-uvm nvidia-modeset nvidia-peermem; do
    case "${module}" in
        nvidia*) file="kernel/drivers/video/${module}.ko" ;;
        *) file="kernel/drivers/base/${module}.ko" ;;
    esac
    [[ -f "${base}/${file}" ]] || exit 1
    echo "insmod ${base}/${file}"
done
EOF
chmod +x "${WORK_DIR}/bin/modprobe"

cat > "${WORK_DIR}/bin/modinfo" <<'EOF'
#!/usr/bin/env bash
root=/
kernel=
module=
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b) root=$2; shift 2 ;;
        -k) kernel=$2; shift 2 ;;
        *) module=$1; shift ;;
    esac
done
[[ -f "${root%/}/lib/modules/${kernel}/kernel/drivers/video/${module}.ko" ]]
EOF
chmod +x "${WORK_DIR}/bin/modinfo"

MODULE_TREE_MODPROBE="${WORK_DIR}/bin/modprobe"
MODULE_TREE_MODINFO="${WORK_DIR}/bin/modinfo"
export MODULE_TREE_MODPROBE MODULE_TREE_MODINFO

_mellanox_devices_present() {
    return 0
}

_gpu_direct_rdma_enabled() {
    [[ "${GPU_DIRECT_RDMA_ENABLED}" == "true" ]]
}

source "${REPO_ROOT}/ubuntu22.04/module-tree-cache.sh"

assert_pass() {
    local name=$1
    shift
    if "$@"; then
        echo "PASS: ${name}"
    else
        echo "FAIL: ${name}"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
}

assert_fail() {
    local name=$1
    shift
    if "$@"; then
        echo "FAIL: ${name} (unexpected success)"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    else
        echo "PASS: ${name}"
    fi
}

create_module_tree() {
    local tree="${MODULE_TREE_MODULES_ROOT}/${KERNEL_VERSION}" module
    rm -rf "${tree}"
    mkdir -p "${tree}/kernel/drivers/base" "${tree}/kernel/drivers/video"
    for module in i2c_core ipmi_msghandler ipmi_devintf; do
        printf 'base-%s\n' "${module}" > "${tree}/kernel/drivers/base/${module}.ko"
    done
    for module in nvidia nvidia-uvm nvidia-modeset nvidia-peermem; do
        printf 'driver-%s\n' "${module}" > "${tree}/kernel/drivers/video/${module}.ko"
    done
    printf 'dependency metadata\n' > "${tree}/modules.dep"
    printf 'alias metadata\n' > "${tree}/modules.alias"
}

create_loaded_modules() {
    local module
    rm -rf "${MODULE_TREE_SYS_MODULE_ROOT}"
    for module in nvidia nvidia_uvm nvidia_modeset nvidia_peermem; do
        mkdir -p "${MODULE_TREE_SYS_MODULE_ROOT}/${module}"
        : > "${MODULE_TREE_SYS_MODULE_ROOT}/${module}/refcnt"
        printf '580.1.2\n' > "${MODULE_TREE_SYS_MODULE_ROOT}/${module}/version"
        printf 'src-%s\n' "${module}" > "${MODULE_TREE_SYS_MODULE_ROOT}/${module}/srcversion"
    done
}

cache_file_for() {
    local suffix=$1 snapshot
    snapshot=$(_module_tree_current_snapshot) || return 1
    printf '%s/rootfs/lib/modules/%s/%s\n' "${snapshot}" "${KERNEL_VERSION}" "${suffix}"
}

fast_path_resources_available() {
    module_tree_usable || _all_required_modules_loaded
}

create_module_tree
create_loaded_modules

assert_pass "all configured modules are loaded" _all_required_modules_loaded
assert_pass "publish cache" module_tree_save
assert_pass "published cache is usable" module_tree_usable

rm -rf "${MODULE_TREE_MODULES_ROOT:?}/${KERNEL_VERSION}"
assert_pass "restore cache into a fresh rootfs" module_tree_restore
assert_pass "restored peermem module exists" test -f \
    "${MODULE_TREE_MODULES_ROOT}/${KERNEL_VERSION}/kernel/drivers/video/nvidia-peermem.ko"

rm -rf "${MODULE_TREE_SYS_MODULE_ROOT}/nvidia_peermem"
assert_pass "cache remains usable when peermem must be reloaded" module_tree_usable
assert_fail "required-module fallback detects missing peermem" _all_required_modules_loaded
assert_pass "cache replaces the missing-module fallback" fast_path_resources_available
rm -rf "${MODULE_TREE_SYS_MODULE_ROOT}/nvidia_uvm"
assert_fail "cache does not replace a missing core module" _core_driver_modules_loaded
create_loaded_modules

DRIVER_CONFIG_DIGEST=digest-b
export DRIVER_CONFIG_DIGEST
assert_fail "digest mismatch rejects cache" module_tree_usable
DRIVER_CONFIG_DIGEST=digest-a
export DRIVER_CONFIG_DIGEST

current_target=$(readlink "${MODULE_TREE_CACHE_DIR}/current")
DRIVER_CONFIG_DIGEST=digest-space-check
MODULE_TREE_CACHE_MIN_FREE_MB=999999999
export DRIVER_CONFIG_DIGEST MODULE_TREE_CACHE_MIN_FREE_MB
assert_pass "space refusal remains non-fatal" module_tree_save
assert_pass "space refusal retains the previous snapshot" test \
    "$(readlink "${MODULE_TREE_CACHE_DIR}/current")" = "${current_target}"
DRIVER_CONFIG_DIGEST=digest-a
MODULE_TREE_CACHE_MIN_FREE_MB=0
export DRIVER_CONFIG_DIGEST MODULE_TREE_CACHE_MIN_FREE_MB

rm -f "${MODULE_TREE_CACHE_DIR}/current"
ln -s 'snapshots/../../outside' "${MODULE_TREE_CACHE_DIR}/current"
assert_fail "cache target traversal is rejected" module_tree_usable
rm -f "${MODULE_TREE_CACHE_DIR}/current"
ln -s "${current_target}" "${MODULE_TREE_CACHE_DIR}/current"

cached_nvidia=$(cache_file_for "kernel/drivers/video/nvidia.ko")
external_module="${WORK_DIR}/external-nvidia.ko"
cp "${cached_nvidia}" "${external_module}"
rm -f "${cached_nvidia}"
ln -s "${external_module}" "${cached_nvidia}"
assert_fail "symlinked cache members are rejected" module_tree_usable
rm -f "${cached_nvidia}"
cp "${external_module}" "${cached_nvidia}"
printf 'x' > "${cached_nvidia}"
assert_fail "truncated module rejects cache" module_tree_usable

rm -rf "${MODULE_TREE_CACHE_DIR}"
create_module_tree
create_loaded_modules
assert_pass "loaded modules permit an unseeded fast path" fast_path_resources_available
rm -rf "${MODULE_TREE_SYS_MODULE_ROOT}/nvidia_peermem"
assert_fail "missing cache and module reject the fast path" fast_path_resources_available
create_loaded_modules
assert_pass "republish after corruption" module_tree_save
printf 'occupied\n' > "${MODULE_TREE_MODULES_ROOT}/${KERNEL_VERSION}/occupied"
assert_fail "restore refuses a non-empty destination" module_tree_restore

MODULE_TREE_CACHE_MAX_MB=0
export MODULE_TREE_CACHE_MAX_MB
assert_fail "zero size limit disables cache" module_tree_usable

if [[ "${FAILURE_COUNT}" -gt 0 ]]; then
    echo "${FAILURE_COUNT} case(s) failed"
    exit 1
fi
echo "All module-tree cache cases passed"
