#!/usr/bin/env bash
# Unit tests for the NVLink5+ helpers in every nvidia-driver script.
#
# The functions are extracted from each script and run against a fake sysfs
# tree (SYSFS_ROOT), so no GPU, InfiniBand device or root access is needed.
# Property checks use a fixed RANDOM seed so failures are reproducible.
#
# Usage: tests/unit/nvlink5-detection.sh

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS="$(cd "$REPO_ROOT" && ls ubuntu*/nvidia-driver ubuntu*/precompiled/nvidia-driver \
    rhel*/nvidia-driver rhel*/precompiled/nvidia-driver 2>/dev/null)"
FUNCS="_assert_nvlink5_system _ensure_nvlink5_prerequisites _nvlink5_fabric_ready"

pass=0
fail=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL [$script] $*"; }

# Print the body of shell function $1 from file $2.
extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\) *[({]" { p = 1 }
        p { print }
        p && /^[)}]$/ { exit }
    ' "$2"
}

new_sysfs() {
    rm -rf "$WORK/sys"
    mkdir -p "$WORK/sys/bus/pci/devices" "$WORK/sys/module" "$WORK/sys/class"
    export SYSFS_ROOT="$WORK/sys"
}

# add_pci <bdf> <vendor> <vpd-content|""> : "" means no vpd attribute
add_pci() {
    d="$SYSFS_ROOT/bus/pci/devices/$1"
    mkdir -p "$d"
    echo "$2" > "$d/vendor"
    if [ -n "$3" ]; then
        # VPD is binary; pad with NUL bytes like a real read of the attribute.
        printf 'PN\0MCX750500B-0D00\0%s\0\0' "$3" > "$d/vpd"
    fi
}

add_modules() { for m in "$@"; do mkdir -p "$SYSFS_ROOT/module/$m"; done; }

# Fake `nvidia-smi -q` output: one argument per GPU, "State/Status".
smi_q() {
    i=0
    printf '==============NVSMI LOG==============\n\nAttached GPUs : %s\n' "$#"
    for gpu in "$@"; do
        printf 'GPU 00000000:%02X:00.0\n' $((i + 0x18))
        printf '    Product Name                          : NVIDIA B200\n'
        printf '    Persistence Mode                      : Enabled\n'
        printf '    Fabric\n'
        printf '        State                             : %s\n' "${gpu%%/*}"
        printf '        Status                            : %s\n' "${gpu##*/}"
        printf '        CliqueId                          : 32766\n'
        printf '    Performance State                     : P0\n'
        i=$((i + 1))
    done
}

run_suite() {
    unset NVLINK5_SYSTEM NVLINK5_PREREQ_TIMEOUT_SECONDS

    # --- detection: must not depend on mlx5_ib (/sys/class/infiniband) ---
    new_sysfs; add_pci 0000:3a:00.0 0x15b3 "SMDL=SW_MNG"
    if _assert_nvlink5_system >/dev/null; then ok; else
        bad "CX7 bridge with SW_MNG in PCI VPD and no mlx5_ib must be detected"; fi

    new_sysfs; add_pci 0000:3a:00.0 0x15b3 "SMDL=0"
    if _assert_nvlink5_system >/dev/null; then
        bad "Mellanox NIC without SW_MNG must not be detected"; else ok; fi

    new_sysfs; add_pci 0000:5b:00.0 0x8086 "SMDL=SW_MNG"
    if _assert_nvlink5_system >/dev/null; then
        bad "non-Mellanox device must be ignored even if VPD matches"; else ok; fi

    new_sysfs; add_pci 0000:3a:00.0 0x15b3 ""
    if _assert_nvlink5_system >/dev/null; then
        bad "Mellanox device without VPD attribute must not be detected"; else ok; fi

    new_sysfs
    if _assert_nvlink5_system >/dev/null; then
        bad "empty PCI tree must not be detected"; else ok; fi

    # --- operator override ---
    new_sysfs
    if NVLINK5_SYSTEM=true _assert_nvlink5_system >/dev/null; then ok; else
        bad "NVLINK5_SYSTEM=true must force detection"; fi
    new_sysfs; add_pci 0000:3a:00.0 0x15b3 "SMDL=SW_MNG"
    if NVLINK5_SYSTEM=false _assert_nvlink5_system >/dev/null; then
        bad "NVLINK5_SYSTEM=false must disable detection"; else ok; fi

    # Property: any value outside auto|true|false behaves exactly like auto.
    RANDOM=1068
    for _ in $(seq 1 25); do
        v="x$RANDOM$RANDOM"
        for has in "SMDL=SW_MNG" "SMDL=0"; do
            new_sysfs; add_pci 0000:3a:00.0 0x15b3 "$has"
            NVLINK5_SYSTEM=auto _assert_nvlink5_system >/dev/null; want=$?
            NVLINK5_SYSTEM="$v" _assert_nvlink5_system >/dev/null; got=$?
            if [ "$want" = "$got" ]; then ok; else
                bad "NVLINK5_SYSTEM='$v' differs from auto (vpd=$has)"; fi
        done
    done

    # --- prerequisites: fail closed with a named error, never hang ---
    # Property: for every subset of the required modules, the check passes
    # only when all are present, and the error names exactly the missing ones.
    all="mlx5_core mlx5_ib ib_umad"
    for mask in 0 1 2 3 4 5 6 7; do
        new_sysfs; present=""; missing=""; bit=1
        for m in $all; do
            if [ $((mask & bit)) -ne 0 ]; then present="$present $m"; else missing="$missing $m"; fi
            bit=$((bit * 2))
        done
        # shellcheck disable=SC2086
        add_modules $present
        out="$(NVLINK5_PREREQ_TIMEOUT_SECONDS=0 _ensure_nvlink5_prerequisites 2>&1)"; rc=$?
        if [ -z "$missing" ]; then
            if [ $rc -eq 0 ]; then ok; else bad "all modules present must pass: $out"; fi
            continue
        fi
        if [ $rc -ne 0 ]; then ok; else bad "missing:$missing must fail"; fi
        case "$out" in *"NVLINK5_PREREQ_MISSING:$missing"*) ok ;;
            *) bad "error must read 'NVLINK5_PREREQ_MISSING:$missing', got: $out" ;; esac
    done

    # --- readiness: fabric registration must complete on every GPU ---
    if smi_q Completed/Success Completed/Success | _nvlink5_fabric_ready; then ok; else
        bad "all GPUs Completed/Success must be ready"; fi
    if smi_q Completed/Success "In Progress/N/A" | _nvlink5_fabric_ready; then
        bad "a GPU still In Progress must not be ready"; else ok; fi
    if smi_q Completed/Success Completed/Failure | _nvlink5_fabric_ready; then
        bad "a GPU with Status Failure must not be ready"; else ok; fi
    if printf 'No devices were found\n' | _nvlink5_fabric_ready; then
        bad "no GPUs must not be ready"; else ok; fi

    # Property: ready iff every GPU (1..8) reports Completed/Success.
    RANDOM=802
    states=("Completed/Success" "Completed/Success" "Completed/Failure" "In Progress/N/A" "Not Started/N/A")
    for _ in $(seq 1 40); do
        n=$((RANDOM % 8 + 1)); gpus=""; want=0
        for _ in $(seq 1 $n); do
            s="${states[$((RANDOM % ${#states[@]}))]}"
            gpus="$gpus|$s"
            [ "$s" = "Completed/Success" ] || want=1
        done
        IFS='|' read -r -a arr <<< "${gpus#|}"
        smi_q "${arr[@]}" | _nvlink5_fabric_ready; got=$?
        if [ "$want" = "$got" ]; then ok; else bad "fabric ready mismatch for:$gpus"; fi
    done
}

for script in $SCRIPTS; do
    for fn in $FUNCS; do unset -f "$fn"; done
    for fn in $FUNCS; do
        body="$(extract "$fn" "$REPO_ROOT/$script")"
        if [ -z "$body" ]; then bad "function $fn not found"; continue; fi
        eval "$body"
    done
    run_suite
done

# All copies must stay identical so the distros cannot drift apart.
for fn in $FUNCS; do
    n="$(for s in $SCRIPTS; do extract "$fn" "$REPO_ROOT/$s" | cksum; done | sort -u | wc -l)"
    script="all"
    if [ "$n" -eq 1 ]; then ok; else bad "$fn differs across scripts ($n variants)"; fi
done

echo "nvlink5 unit tests: $pass passed, $fail failed ($(echo "$SCRIPTS" | wc -w | tr -d ' ') scripts)"
[ "$fail" -eq 0 ]
