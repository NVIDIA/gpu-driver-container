# Ubuntu 26.04

Driver container for Ubuntu 26.04.

For the passthrough/baremetal driver type, the NVIDIA driver is installed from the NVIDIA CUDA
APT repository (`ubuntu2604`) instead of the `.run` installer:

- At image build, the version-specific `nvidia-driver-pinning-<version>` package pins the whole
  driver tree to `DRIVER_VERSION`, the full driver userspace is preinstalled into the image, and
  the kernel module packages are baked into a local `file:` APT repo. The CUDA network repository
  is then removed from the APT sources.
- At container start, the kernel headers for the running kernel are installed, then the driver
  metapackage (`nvidia-open` for `KERNEL_MODULE_TYPE=open`/`auto`, `cuda-drivers` for
  `proprietary`) is installed from the local repo and DKMS builds the kernel modules. Network
  access is needed only for the kernel headers.

The vGPU driver type continues to install from a user-supplied `.run` file placed in `drivers/`.

See https://github.com/NVIDIA/nvidia-docker/wiki/Driver-containers-(Beta)
