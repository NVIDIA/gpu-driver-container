# Introduction

NVIDIA Virtual GPU (vGPU) enables multiple virtual machines (VMs) to have simultaneous, direct access to a single physical GPU, using the same NVIDIA graphics drivers that are deployed on non-virtualized operating systems.
By doing this, NVIDIA vGPU provides VMs with unparalleled graphics performance, compute performance, and application compatibility, together with the cost-effectiveness and scalability brought about by sharing a GPU among multiple workloads.
Under the control of the NVIDIA Virtual GPU Manager running under the hypervisor, NVIDIA physical GPUs are capable of supporting multiple virtual GPU devices (vGPUs) that can be assigned directly to guest VMs.
To learn more, refer to the [NVIDIA vGPU Software Documentation](https://docs.nvidia.com/grid/).

This repository contains scripts for building a containerized NVIDIA vGPU Manager.

## Prerequisites

* Access to NVIDIA vGPU Software from the [NVIDIA Licensing Portal](https://nvid.nvidia.com/dashboard/#/dashboard)

## Build

Download the NVIDIA vGPU Software from the [NVIDIA Licensing Portal](https://nvid.nvidia.com/dashboard/#/dashboard):

* Login to the NVIDIA Licensing Portal and navigate to the `Software Downloads` section.
* The NVIDIA vGPU Software is located in the Software Downloads section of the NVIDIA Licensing Portal.
* The vGPU Software bundle is packaged as a zip file. Download and unzip the bundle to obtain the NVIDIA vGPU Manager for Linux (``NVIDIA-Linux-x86_64-<version>-vgpu-kvm.run`` file)

Clone the driver container repository:

```
$ git clone https://gitlab.com/nvidia/container-images/driver && cd driver
```

Enter the vgpu-manager directory for your OS:

```
$ cd vgpu-manager/<os>
```

Copy the NVIDIA vGPU Manager runfile from the extracted zip file:

```
$ cp <local-driver-download-directory>/*-vgpu-kvm.run ./
```

Set the following environment variables:

* ``PRIVATE_REGISTRY`` - name of private registry used to store driver image
* ``VERSION`` - NVIDIA vGPU Manager version downloaded from NVIDIA Software Portal
* ``OS_TAG`` - this must match the Guest OS version. In the below example ``ubuntu20.04`` is used. For RedHat OpenShift this should be set to ``rhcos4.x`` where x is the supported minor OCP version.
* ``CUDA_VERSION`` - CUDA base image version to build the driver image with

```
$ export PRIVATE_REGISTRY=my/private/registry VERSION=510.73.06 OS_TAG=ubuntu20.04 CUDA_VERSION=11.7.1
```

Build the NVIDIA vGPU Manager image:

```
$ docker build \
    --build-arg DRIVER_VERSION=${VERSION} \
    --build-arg CUDA_VERSION=${CUDA_VERSION} \
    -t ${PRIVATE_REGISTRY}/vgpu-manager:${VERSION}-${OS_TAG} .
```
