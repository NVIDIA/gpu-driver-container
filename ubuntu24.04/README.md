# Ubuntu 24.04 [![build status](https://gitlab.com/nvidia/driver/badges/master/build.svg)](https://gitlab.com/nvidia/driver/commits/master)

See https://github.com/NVIDIA/nvidia-docker/wiki/Driver-containers-(Beta)

## Building test images from a locally stored driver

To build an image from a driver `.run` file that is not published on the
public download server (for example a release candidate or test build):

1. Copy the run file(s) into `drivers/`:
   `NVIDIA-Linux-x86_64-<version>.run` and/or
   `NVIDIA-Linux-aarch64-<version>.run`. Each platform image only keeps the
   run file matching its architecture.
2. Optionally copy the matching local driver repository package(s)
   (`nvidia-driver-local-repo-ubuntu2404-<version>_*_<arch>.deb`) into
   `drivers/` as well. This provides the extra packages (fabric manager,
   libnvidia-nscq, libnvsdm, nvlsm, nvidia-imex) that are otherwise installed
   from the public CUDA repository. If omitted, extra packages are skipped and
   the resulting image must not be used on NVSwitch-based systems.
3. Build with `LOCAL_DRIVER=true`:

   ```sh
   docker buildx build --platform linux/amd64,linux/arm64 \
     --build-arg LOCAL_DRIVER=true \
     --build-arg DRIVER_VERSION=<version> \
     --build-arg DRIVER_BRANCH=<branch> \
     --build-arg GOLANG_VERSION=<golang-version from versions.mk> \
     -t <registry>/driver:<version>-ubuntu24.04 .
   ```
