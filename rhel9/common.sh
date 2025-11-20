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

# Build driver configuration for state comparison
_build_driver_config() {
	local nvidia_params="" nvidia_uvm_params="" nvidia_modeset_params="" nvidia_peermem_params=""
	
	# Read module parameters from conf files
	if [ -f "/drivers/nvidia.conf" ]; then
		nvidia_params=$(cat "/drivers/nvidia.conf" | tr '\n' ' ')
	fi
	if [ -f "/drivers/nvidia-uvm.conf" ]; then
		nvidia_uvm_params=$(cat "/drivers/nvidia-uvm.conf" | tr '\n' ' ')
	fi
	if [ -f "/drivers/nvidia-modeset.conf" ]; then
		nvidia_modeset_params=$(cat "/drivers/nvidia-modeset.conf" | tr '\n' ' ')
	fi
	if [ -f "/drivers/nvidia-peermem.conf" ]; then
		nvidia_peermem_params=$(cat "/drivers/nvidia-peermem.conf" | tr '\n' ' ')
	fi
	
	local config="DRIVER_VERSION=${DRIVER_VERSION}
DRIVER_TYPE=${DRIVER_TYPE:-passthrough}
KERNEL_VERSION=$(uname -r)
GPU_DIRECT_RDMA_ENABLED=${GPU_DIRECT_RDMA_ENABLED:-false}
USE_HOST_MOFED=${USE_HOST_MOFED:-false}
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE:-auto}
NVIDIA_MODULE_PARAMS=${nvidia_params}
NVIDIA_UVM_MODULE_PARAMS=${nvidia_uvm_params}
NVIDIA_MODESET_MODULE_PARAMS=${nvidia_modeset_params}
NVIDIA_PEERMEM_MODULE_PARAMS=${nvidia_peermem_params}"

	# Append config file contents directly
	for conf_file in nvidia.conf nvidia-uvm.conf nvidia-modeset.conf nvidia-peermem.conf; do
		if [ -f "/drivers/$conf_file" ]; then
			config="${config}
$(cat "/drivers/$conf_file")"
		fi
	done

	echo "$config"
}

# Check if fast path should be used (driver already loaded with matching config)
_should_use_fast_path() {
    [ -f /sys/module/nvidia/refcnt ] && [ -f /run/nvidia/driver-config.state ] || return 1
    local current_config=$(_build_driver_config)
    local stored_config=$(cat /run/nvidia/driver-config.state 2>/dev/null || echo "")
    [ "${current_config}" = "${stored_config}" ]
}
