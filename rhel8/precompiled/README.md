# RHCOS UBI8 [![build status](https://gitlab.com/nvidia/driver/badges/master/build.svg)](https://gitlab.com/nvidia/driver/commits/master)

See https://github.com/NVIDIA/nvidia-docker/wiki/Driver-containers-(Beta)

To manually build a specific `{kernel/driver}` image first you need a Red Hat Subscription Manager (RHSM) activation key and a valid pull secret. 

* [Creating Red Hat Customer Portal Activation Keys](https://access.redhat.com/articles/1378093)
* [Downloading and updating pull secrets](https://access.redhat.com/documentation/en-us/openshift_cluster_manager/2023/html/managing_clusters/assembly-managing-clusters#downloading_and_updating_pull_secrets)

to define the following environment variables:

```bash
RHSM_ORG ?=<SECRET>
RHSM_ACTIVATIONKEY?=<SECRET>
PULL_SECRET_FILE?=<SECRET>
```

Then run 

```bash
make build-matrix
```

A JSON file `build-matrix-${DATE}.json` will be generated. Select a kernel version (`kernel`) from the generated JSON file and define the following environment variable:

```
KERNEL_VERSION=<KERNEL>
```

optionally, override any of the following variables:

```bash
IMAGE_REGISTRY=<REGISTRY>
TARGET_ARCH=<ARCH>
CUDA_VERSION=<VERSION>
DRIVER_BRANCH=<BRANCH>
```

Then you can build the image with:
    
```bash
make image
```

Now you may push the image to the registry:

```bash
docker push ${IMAGE_REGISTRY}/driver-toolkit:${RHEL_VERSION}-${KERNEL_VERSION}
```

## Note on Red Hat OpenShift

The command produces an image named as `${IMAGE_REGISTRY}/driver-toolkit:${RHEL_VERSION}-${KERNEL_VERSION}`. If you are going to use it with the [NVIDIA GPU Operator on OpenShift](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/openshift/contents.html), `${IMAGE_REGISTRY}/driver:${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG}` will be probably expected.

Define the missing variables, then tag and push the image. 
For example:

```bash
DRIVER_VERSION=525.105.17
OS_TAG=rhcos4.12

docker tag \
    ${IMAGE_REGISTRY}/driver-toolkit:${RHEL_VERSION}-${KERNEL_VERSION} \
    ${IMAGE_REGISTRY}/driver:${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG}

docker push ${IMAGE_REGISTRY}/driver:${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG}

```