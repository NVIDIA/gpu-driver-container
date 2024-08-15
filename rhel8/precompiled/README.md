# Precompiled NVIDIA GPU driver container image for RHEL 8.x and 9.x (RHCOS 4.12 and 4.13)

The procedure is based on [building custom kmod packages](https://github.com/NVIDIA/yum-packaging-precompiled-kmod) to allow support for a wide range of kernel versions.

**Prerequisites**:

* A Red Hat account with access to Red Hat Hybrid Cloud Console and Red Hat Subscription Management (RHSM).

## Image build

1. Create a [Red Hat Customer Portal Activation Key](https://access.redhat.com/articles/1378093) and note your Red Hat Subscription Management (RHSM) organization ID. These will be used to install packages during a build. Save the values to file, e.g., `$HOME/rhsm_org` and `$HOME/rhsm_activationkey`.

2. Download a [Red Hat OpenShift pull secret](https://access.redhat.com/documentation/en-us/openshift_cluster_manager/2023/html/managing_clusters/assembly-managing-clusters#downloading_and_updating_pull_secrets).

3. Find out the Driver Toolkit (DTK) image for your target Red Hat OpenShift version, e.g.:

    ```
    # oc adm release info --image-for=driver-toolkit quay.io/openshift-release-dev/ocp-release:4.12.13-x86_64
    quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:6afc764e57b39493f57dd20a714cf9bee8cd02a34bf361570f68888b4af753ad
    ```

4. Find out the kernel version of your target OpenShift cluster.

    For example, on a live system

    ```
    # uname -r
    4.18.0-372.51.1.el8_6.x86_64
    ```

    Or by inspecting the content of the DTK image for the target system

    ```
    # podman run --authfile $HOME/pull-secret.txt --rm -ti quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:6afc764e57b39493f57dd20a714cf9bee8cd02a34bf361570f68888b4af753ad ls /lib/modules
    4.18.0-372.51.1.el8_6.x86_64
    ...
    ```

5. Set environment variables, build and push the image:

    ```
    export RHSM_ORG_FILE=$HOME/rhsm_org
    export RHSM_ACTIVATIONKEY_FILE=$HOME/rhsm_activationkey
    export PULL_SECRET_FILE=$HOME/pull-secret.txt

    export DRIVER_TOOLKIT_IMAGE=quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:6afc764e57b39493f57dd20a714cf9bee8cd02a34bf361570f68888b4af753ad

    export KERNEL_VERSION=4.18.0-513.9.1.el8_9.x86_64
    export RHEL_VERSION=8.9
    export CUDA_VERSION=12.1.0
    export CUDA_DIST=ubi8
    export DRIVER_EPOCH=1
    export DRIVER_VERSION=535.183.06
    export OS_TAG=rhcos4.13

    make image image-push
    ```

    When building for RHEL 9.x (RHCOS 4.13), set `CUDA_DIST=ubi9`.

    When building a vGPU driver, set `export DRIVER_TYPE=vgpu` (the default is `passthrough`).

    Optionally, override the `IMAGE_REGISTRY`, `IMAGE_NAME`, and/or `CONTAINER_TOOL` (docker/podman). You can also override `BUILDER_USER` and/or `BUILDER_EMAIL` if you want, otherwise your Git username and email will be used. See the [Makefile](Makefile) for all available variables.

    **NOTE:** The default image name is `driver` for passthrough and `vgpu-guest-driver` for vGPU.

## NVIDIA GPU operator

In order to be used with the NVIDIA GPU Operator on Red Hat OpenShift, the image tag must follow the format `${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG}`, and the full name will look like `nvcr.io/nvidia/driver:535.183.06-4.18.0-513.9.1.el8_9.x86_64-rhcos4.13`.


Define the `ClusterPolicy` resource to make use of the pre-compiled driver image, e.g.:

```
  driver:
    usePrecompiled: true
    image: driver
    repository: nvcr.io/nvidia
    version: 535.183.06
```

Find more information in the [Precompiled Driver Containers](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/precompiled-drivers.html) documentation.
