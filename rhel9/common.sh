#!/usr/bin/env bash
# Copyright (c) 2018-2023, NVIDIA CORPORATION. All rights reserved.

GPU_DIRECT_RDMA_ENABLED="${GPU_DIRECT_RDMA_ENABLED:-false}"
GDS_ENABLED="${GDS_ENABLED:-false}"
GDRCOPY_ENABLED="${GDRCOPY_ENABLED:-false}"

# Check if mellanox devices are present
_mellanox_devices_present() {
    devices_found=0
    for dev in /sys/bus/pci/devices/*; do
        read vendor < $dev/vendor
        if [ "$vendor" = "0x15b3" ]; then
            echo "Mellanox device found at $(basename $dev)"
            return 0
        fi
    done
    echo "No Mellanox devices were found..."
    return 1
}

# Check if GPU Direct RDMA is enabled
_gpu_direct_rdma_enabled() {
    if [ "${GPU_DIRECT_RDMA_ENABLED}" = "true" ]; then
        # check if mellanox cards are present
        if  _mellanox_devices_present; then
            return 0
        fi
    fi
    return 1
}

# Check if GDS is enabled
_gpu_direct_storage_enabled() {
    if [ "${GDS_ENABLED}" = "true" ]; then
        return 0
    fi
    return 1
}

# Check if GDRCopy is enabled
_gdrcopy_enabled() {
    if [ "${GDRCOPY_ENABLED}" = "true" ]; then
        return 0
    fi
    return 1
}

# Read a config file and convert newlines to spaces
_read_conf_file() {
    local file="$1"
    [ -f "$file" ] && tr '\n' ' ' < "$file"
}

# Build driver configuration for state comparison
# Note: Variables are expected to be set by the sourcing script (nvidia-driver)
_build_driver_config() {
    cat <<EOF
DRIVER_VERSION=${DRIVER_VERSION}
DRIVER_TYPE=${DRIVER_TYPE}
KERNEL_VERSION=$(uname -r)
GPU_DIRECT_RDMA_ENABLED=${GPU_DIRECT_RDMA_ENABLED}
USE_HOST_MOFED=${USE_HOST_MOFED}
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE}
NVIDIA_MODULE_PARAMS=$(_read_conf_file /drivers/nvidia.conf)
NVIDIA_UVM_MODULE_PARAMS=$(_read_conf_file /drivers/nvidia-uvm.conf)
NVIDIA_MODESET_MODULE_PARAMS=$(_read_conf_file /drivers/nvidia-modeset.conf)
NVIDIA_PEERMEM_MODULE_PARAMS=$(_read_conf_file /drivers/nvidia-peermem.conf)
EOF
}

# Check if fast path should be used (driver already loaded with matching config)
_should_use_fast_path() {
    [ -f /sys/module/nvidia/refcnt ] && [ -f /run/nvidia/nvidia-driver.state ] || return 1
    local current_config=$(_build_driver_config)
    local stored_config=$(cat /run/nvidia/nvidia-driver.state 2>/dev/null || echo "")
    [ "${current_config}" = "${stored_config}" ]
}
