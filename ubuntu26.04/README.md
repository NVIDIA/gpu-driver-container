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

## Building test images from a locally stored driver

To build an image from a driver version that is not published in the CUDA APT
repository (for example a release candidate or test build):

1. Copy the matching local driver repository package(s)
   (`nvidia-driver-local-repo-ubuntu2604-<version>_*_<arch>.deb`) into
   `drivers/`. The package provides the driver packages and the extra packages
   (fabric manager, libnvidia-nscq, libnvsdm, nvlsm, nvidia-imex) in place of
   the CUDA repository. Each platform image uses only the package matching its
   architecture. The package is mounted only into the driver package install
   step and is not stored in an image layer. No `.run` file is needed.
2. Build with `LOCAL_DRIVER=true`:

   ```sh
   docker buildx build --platform linux/amd64,linux/arm64 \
     --build-arg LOCAL_DRIVER=true \
     --build-arg DRIVER_VERSION=<version> \
     --build-arg DRIVER_BRANCH=<branch> \
     --build-arg GOLANG_VERSION=<golang-version from versions.mk> \
     -t <registry>/driver:<version>-ubuntu26.04 .
   ```
