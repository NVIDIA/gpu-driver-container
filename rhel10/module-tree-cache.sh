#!/usr/bin/env bash

MODULE_TREE_CACHE_FORMAT=1
MODULE_TREE_CACHE_DIR="${MODULE_TREE_CACHE_DIR:-${RUN_DIR:-/run/nvidia}/module-tree-cache}"
MODULE_TREE_ROOTFS="${MODULE_TREE_ROOTFS:-/}"
MODULE_TREE_MODULES_ROOT="${MODULE_TREE_MODULES_ROOT:-${MODULE_TREE_ROOTFS%/}/lib/modules}"
MODULE_TREE_SYS_MODULE_ROOT="${MODULE_TREE_SYS_MODULE_ROOT:-/sys/module}"
MODULE_TREE_MODPROBE="${MODULE_TREE_MODPROBE:-modprobe}"
MODULE_TREE_MODINFO="${MODULE_TREE_MODINFO:-modinfo}"
MODULE_TREE_CACHE_MAX_MB="${MODULE_TREE_CACHE_MAX_MB:-512}"
MODULE_TREE_CACHE_MIN_FREE_MB="${MODULE_TREE_CACHE_MIN_FREE_MB:-64}"

_module_tree_log() {
    echo "module-tree-cache operation=$1 result=$2 reason=$3 bytes=${4:-0}"
}

_module_tree_kernel_release() {
    if [ -n "${MODULE_TREE_KERNEL_RELEASE:-}" ]; then
        printf '%s\n' "${MODULE_TREE_KERNEL_RELEASE}"
    else
        uname -r
    fi
}

_module_tree_enabled() {
    [ "${DRIVER_TYPE:-}" != "vgpu" ] || return 1
    [ -n "${DRIVER_CONFIG_DIGEST:-}" ] || return 1
    case "${MODULE_TREE_CACHE_MAX_MB}" in
        ''|*[!0-9]*) return 1 ;;
        0) return 1 ;;
    esac
}

_module_tree_required_modules() {
    printf '%s\n' nvidia nvidia-uvm nvidia-modeset
    if _gpu_direct_rdma_enabled; then
        printf '%s\n' nvidia-peermem
    fi
}

_module_tree_sysfs_name() {
    printf '%s\n' "${1//-/_}"
}

_all_required_modules_loaded() {
    local module sysfs_name

    while IFS= read -r module; do
        sysfs_name=$(_module_tree_sysfs_name "${module}")
        [ -f "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}/refcnt" ] || return 1
    done < <(_module_tree_required_modules)
}

_core_driver_modules_loaded() {
    local module sysfs_name

    for module in nvidia nvidia-uvm nvidia-modeset; do
        sysfs_name=$(_module_tree_sysfs_name "${module}")
        [ -f "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}/refcnt" ] || return 1
    done
}

_module_tree_manifest_value() {
    local manifest=$1 key=$2
    awk -F= -v key="${key}" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "${manifest}"
}

_module_tree_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    else
        shasum -a 256 | awk '{print $1}'
    fi
}

_module_tree_file_size() {
    stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1"
}

_module_tree_path_has_no_symlink() {
    local root=$1 relative=$2 component
    local current="${root}"
    local -a components

    IFS='/' read -r -a components <<< "${relative}"
    for component in "${components[@]}"; do
        [ -n "${component}" ] || continue
        current="${current}/${component}"
        [ ! -L "${current}" ] || return 1
    done
}

_module_tree_identity() {
    printf 'format=%s\nkernel_release=%s\ndriver_version=%s\ndriver_config_digest=%s\n' \
        "${MODULE_TREE_CACHE_FORMAT}" \
        "$(_module_tree_kernel_release)" \
        "${DRIVER_VERSION:-}" \
        "${DRIVER_CONFIG_DIGEST:-}"
}

_module_tree_current_snapshot() {
    local target

    [ -L "${MODULE_TREE_CACHE_DIR}/current" ] || return 1
    target=$(readlink "${MODULE_TREE_CACHE_DIR}/current") || return 1
    [[ "${target}" =~ ^snapshots/[0-9a-f]{64}$ ]] || return 1
    [ -d "${MODULE_TREE_CACHE_DIR}/${target}" ] || return 1
    [ ! -L "${MODULE_TREE_CACHE_DIR}/${target}" ] || return 1
    printf '%s\n' "${MODULE_TREE_CACHE_DIR}/${target}"
}

_module_tree_loaded_metadata_matches() {
    local manifest=$1 module sysfs_name expected actual

    while IFS= read -r module; do
        sysfs_name=$(_module_tree_sysfs_name "${module}")
        [ -d "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}" ] || continue

        for field in version srcversion; do
            [ -f "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}/${field}" ] || continue
            expected=$(_module_tree_manifest_value "${manifest}" "${sysfs_name}_${field}")
            [ -n "${expected}" ] || return 1
            actual=$(cat "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}/${field}")
            [ "${actual}" = "${expected}" ] || return 1
        done
    done < <(_module_tree_required_modules)
}

_module_tree_files_valid() {
    local snapshot=$1 kernel=$2 size relative file actual_size

    [ -s "${snapshot}/files" ] && [ ! -L "${snapshot}/files" ] || return 1
    while IFS="$(printf '\t')" read -r size relative; do
        case "${relative}" in
            ''|/*|../*|*/../*|*/..) return 1 ;;
        esac
        file="${snapshot}/rootfs/lib/modules/${kernel}/${relative}"
        _module_tree_path_has_no_symlink "${snapshot}" "rootfs/lib/modules/${kernel}/${relative}" || return 1
        [ -f "${file}" ] && [ ! -L "${file}" ] || return 1
        actual_size=$(_module_tree_file_size "${file}") || return 1
        [ "${actual_size}" = "${size}" ] || return 1
    done < "${snapshot}/files"
}

_module_tree_modules_resolve() {
    local rootfs=$1 kernel=$2 module
    local -a modules=()

    while IFS= read -r module; do
        modules+=("${module}")
        "${MODULE_TREE_MODINFO}" -b "${rootfs}" -k "${kernel}" "${module}" >/dev/null 2>&1 || return 1
    done < <(_module_tree_required_modules)

    # One dependency resolution catches stale modules.* metadata without loading anything.
    "${MODULE_TREE_MODPROBE}" -d "${rootfs}" -S "${kernel}" --show-depends -a "${modules[@]}" >/dev/null 2>&1
}

_module_tree_snapshot_usable() {
    local snapshot=$1 manifest kernel

    manifest="${snapshot}/manifest"
    [ -f "${manifest}" ] && [ ! -L "${manifest}" ] || return 1

    [ "$(_module_tree_manifest_value "${manifest}" format)" = "${MODULE_TREE_CACHE_FORMAT}" ] || return 1
    kernel=$(_module_tree_kernel_release)
    [ "$(_module_tree_manifest_value "${manifest}" kernel_release)" = "${kernel}" ] || return 1
    [ "$(_module_tree_manifest_value "${manifest}" driver_version)" = "${DRIVER_VERSION:-}" ] || return 1
    [ "$(_module_tree_manifest_value "${manifest}" driver_config_digest)" = "${DRIVER_CONFIG_DIGEST:-}" ] || return 1

    _module_tree_loaded_metadata_matches "${manifest}" || return 1
    _module_tree_files_valid "${snapshot}" "${kernel}" || return 1
    _module_tree_modules_resolve "${snapshot}/rootfs" "${kernel}"
}

module_tree_usable() {
    local snapshot

    _module_tree_enabled || return 1
    snapshot=$(_module_tree_current_snapshot) || return 1
    _module_tree_snapshot_usable "${snapshot}"
}

_module_tree_invalidate_current() {
    rm -f "${MODULE_TREE_CACHE_DIR}/current"
}

_module_tree_collect_files() {
    local output=$1 kernel=$2
    local tree="${MODULE_TREE_MODULES_ROOT}/${kernel}"
    local dependencies kind source relative metadata
    local invalid=false
    local -a modules=()

    [ -d "${tree}" ] || return 1
    dependencies=$(mktemp) || return 1
    while IFS= read -r source; do
        modules+=("${source}")
    done < <(_module_tree_required_modules)
    if ! "${MODULE_TREE_MODPROBE}" -d "${MODULE_TREE_ROOTFS}" -S "${kernel}" \
        --show-depends -a "${modules[@]}" > "${dependencies}"; then
        rm -f "${dependencies}"
        return 1
    fi

    : > "${output}"
    while read -r kind source _; do
        [ "${kind}" = "insmod" ] || continue
        while [[ "${source}" == //* ]]; do
            source="/${source#//}"
        done
        case "${source}" in
            "${tree}/"*)
                [ -f "${source}" ] || {
                    invalid=true
                    break
                }
                relative=${source#"${tree}/"}
                printf '%s\n' "${relative}" >> "${output}"
                ;;
            *)
                invalid=true
                break
                ;;
        esac
    done < "${dependencies}"
    rm -f "${dependencies}"
    [ "${invalid}" = "false" ] || return 1

    for metadata in "${tree}"/modules.*; do
        [ -f "${metadata}" ] || continue
        printf '%s\n' "${metadata#"${tree}/"}" >> "${output}"
    done

    LC_ALL=C sort -u -o "${output}" "${output}"
    [ -s "${output}" ]
}

_module_tree_capacity_available() {
    local bytes=$1 max_bytes total_kb available_kb reserve_bytes

    max_bytes=$((MODULE_TREE_CACHE_MAX_MB * 1024 * 1024))
    [ "${bytes}" -le "${max_bytes}" ] || return 1

    read -r total_kb available_kb < <(df -Pk "${MODULE_TREE_CACHE_DIR}" | awk 'NR == 2 {print $2, $4}')
    [ -n "${total_kb:-}" ] && [ -n "${available_kb:-}" ] || return 1
    reserve_bytes=$((total_kb * 1024 / 10))
    if [ "${reserve_bytes}" -lt $((MODULE_TREE_CACHE_MIN_FREE_MB * 1024 * 1024)) ]; then
        reserve_bytes=$((MODULE_TREE_CACHE_MIN_FREE_MB * 1024 * 1024))
    fi
    [ $((available_kb * 1024 - bytes)) -ge "${reserve_bytes}" ]
}

_module_tree_write_manifest() {
    local manifest=$1 module sysfs_name field value

    _module_tree_identity > "${manifest}"
    while IFS= read -r module; do
        sysfs_name=$(_module_tree_sysfs_name "${module}")
        [ -d "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}" ] || continue
        for field in version srcversion; do
            [ -f "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}/${field}" ] || continue
            value=$(cat "${MODULE_TREE_SYS_MODULE_ROOT}/${sysfs_name}/${field}")
            printf '%s_%s=%s\n' "${sysfs_name}" "${field}" "${value}" >> "${manifest}"
        done
    done < <(_module_tree_required_modules)
}

module_tree_save() {
    local kernel identity snapshot snapshot_id stage list relative source destination size total=0
    local link entry

    if ! _module_tree_enabled; then
        _module_tree_log save skipped disabled
        return 0
    fi

    kernel=$(_module_tree_kernel_release)
    [ "${KERNEL_VERSION}" = "${kernel}" ] || {
        _module_tree_log save skipped kernel-version-mismatch
        return 0
    }

    if module_tree_usable; then
        _module_tree_log save skipped unchanged
        return 0
    fi

    mkdir -p "${MODULE_TREE_CACHE_DIR}/snapshots" || {
        _module_tree_log save skipped cache-directory
        return 0
    }

    stage=$(mktemp -d "${MODULE_TREE_CACHE_DIR}/.staging.XXXXXX") || {
        _module_tree_log save skipped staging
        return 0
    }
    mkdir -p "${stage}/rootfs/lib/modules/${kernel}" || {
        rm -rf "${stage}"
        _module_tree_log save skipped staging
        return 0
    }
    list="${stage}/selected"
    if ! _module_tree_collect_files "${list}" "${kernel}"; then
        rm -rf "${stage}"
        _module_tree_log save skipped dependency-closure
        return 0
    fi

    while IFS= read -r relative; do
        source="${MODULE_TREE_MODULES_ROOT}/${kernel}/${relative}"
        size=$(_module_tree_file_size "${source}") || {
            rm -rf "${stage}"
            _module_tree_log save skipped stat
            return 0
        }
        total=$((total + size))
    done < "${list}"

    if ! _module_tree_capacity_available "${total}"; then
        rm -rf "${stage}"
        _module_tree_log save skipped insufficient-space "${total}"
        return 0
    fi

    : > "${stage}/files"
    while IFS= read -r relative; do
        source="${MODULE_TREE_MODULES_ROOT}/${kernel}/${relative}"
        destination="${stage}/rootfs/lib/modules/${kernel}/${relative}"
        mkdir -p "$(dirname "${destination}")" || {
            rm -rf "${stage}"
            _module_tree_log save skipped mkdir "${total}"
            return 0
        }
        if ! cp -Lp "${source}" "${destination}"; then
            rm -rf "${stage}"
            _module_tree_log save skipped copy "${total}"
            return 0
        fi
        size=$(_module_tree_file_size "${destination}") || {
            rm -rf "${stage}"
            _module_tree_log save skipped stat-copy "${total}"
            return 0
        }
        printf '%s\t%s\n' "${size}" "${relative}" >> "${stage}/files"
    done < "${list}"
    rm -f "${list}"
    _module_tree_write_manifest "${stage}/manifest" || {
        rm -rf "${stage}"
        _module_tree_log save skipped manifest "${total}"
        return 0
    }

    identity=$(_module_tree_identity | _module_tree_hash)
    snapshot_id=$(
        {
            printf '%s\n' "${identity}"
            printf '%s\n' "$(basename "${stage}")"
        } | _module_tree_hash
    )
    snapshot="${MODULE_TREE_CACHE_DIR}/snapshots/${snapshot_id}"
    if ! mv "${stage}" "${snapshot}"; then
        rm -rf "${stage}"
        _module_tree_log save skipped publish "${total}"
        return 0
    fi

    link="${MODULE_TREE_CACHE_DIR}/.current.$$"
    rm -f "${link}"
    if ! ln -s "snapshots/${snapshot_id}" "${link}" || ! mv -f "${link}" "${MODULE_TREE_CACHE_DIR}/current"; then
        rm -f "${link}"
        rm -rf "${snapshot}"
        _module_tree_log save skipped publish-link "${total}"
        return 0
    fi

    for entry in "${MODULE_TREE_CACHE_DIR}"/snapshots/*; do
        [ -e "${entry}" ] || continue
        [ "${entry}" = "${snapshot}" ] || rm -rf "${entry}"
    done

    _module_tree_log save published ok "${total}"
    return 0
}

module_tree_restore() {
    local snapshot kernel destination incoming

    _module_tree_enabled || {
        _module_tree_log restore miss unusable
        return 1
    }
    snapshot=$(_module_tree_current_snapshot) || {
        _module_tree_log restore miss unusable
        return 1
    }
    if ! _module_tree_snapshot_usable "${snapshot}"; then
        _module_tree_invalidate_current
        _module_tree_log restore miss unusable
        return 1
    fi

    kernel=$(_module_tree_kernel_release)
    destination="${MODULE_TREE_MODULES_ROOT}/${kernel}"
    if [ -d "${destination}" ] && [ -n "$(find "${destination}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        _module_tree_log restore miss destination-not-empty
        return 1
    fi

    incoming="${MODULE_TREE_MODULES_ROOT}/.${kernel}.incoming.$$"
    rm -rf "${incoming}"
    mkdir -p "${incoming}" || {
        _module_tree_invalidate_current
        _module_tree_log restore miss mkdir
        return 1
    }

    if ! cp -Rp "${snapshot}/rootfs/lib/modules/${kernel}/." "${incoming}/"; then
        rm -rf "${incoming}"
        _module_tree_invalidate_current
        _module_tree_log restore miss copy
        return 1
    fi

    if [ -d "${destination}" ]; then
        rmdir "${destination}" || {
            rm -rf "${incoming}"
            _module_tree_invalidate_current
            _module_tree_log restore miss destination-race
            return 1
        }
    fi
    if ! mv "${incoming}" "${destination}"; then
        rm -rf "${incoming}"
        _module_tree_invalidate_current
        _module_tree_log restore miss rename
        return 1
    fi

    _module_tree_log restore hit ok
    return 0
}
