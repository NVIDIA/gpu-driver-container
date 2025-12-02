#!/usr/bin/env bash
# Copyright (c) 2026, NVIDIA CORPORATION. All rights reserved.

GPU_DIRECT_RDMA_ENABLED="${GPU_DIRECT_RDMA_ENABLED:-false}"

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

_gpu_direct_rdma_enabled() {
    if [ "${GPU_DIRECT_RDMA_ENABLED}" = "true" ]; then
        # check if mellanox cards are present
        if  _mellanox_devices_present; then
            return 0
        fi
    fi
    return 1
}
