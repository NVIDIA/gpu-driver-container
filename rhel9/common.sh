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
