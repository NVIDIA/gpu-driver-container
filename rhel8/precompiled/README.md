# RHCOS UBI8 [![build status](https://gitlab.com/nvidia/driver/badges/master/build.svg)](https://gitlab.com/nvidia/driver/commits/master)

See https://github.com/NVIDIA/nvidia-docker/wiki/Driver-containers-(Beta)

To manually build a specific `{kernel/driver}` image first you need to define
the following environment variables:

```bash
RHSM_ORG ?=<SECRET>
RHSM_ACTIVATIONKEY?=<SECRET>
PULL_SECRET_FILE?=<SECRET>
```

Then run 

```bash
make build-matrix
```

Select a combination of `{kernel/driver}` from the generated json file and
Then you can build the image with:

*NOTE* : the `{kernel/driver}` combination  must be listed at https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/precompiled/
    
```bash
KERNEL_VERSION=<From-build-matrix-${DATE}.json>
make image
```
