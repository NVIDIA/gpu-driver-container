#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

DRIVER_VERSION=${1}
REGISTRY=${2}

# Get the kernel version
kernel_version=$(uname -r)

docker build -t "install-driver:${DRIVER_VERSION}" \
             --build-arg DRIVER_VERSION="${DRIVER_VERSION}" "https://gitlab.com/nvidia/driver.git#master:coreos"

docker run --privileged --name "compile_driver-${DRIVER_VERSION}" "install-driver:${DRIVER_VERSION}" \
	     update --kernel ${kernel_version}

docker commit -m "Compile Linux kernel modules version ${kernel_version} for NVIDIA driver version ${DRIVER_VERSION}" \
	     --change='ENTRYPOINT ["nvidia-driver", "init"]' "compile_driver-${DRIVER_VERSION}" "${REGISTRY}:${DRIVER_VERSION}-${kernel_version}-coreos"

docker save "${REGISTRY}:${DRIVER_VERSION}-${kernel_version}-coreos" -o "${DRIVER_VERSION}-${kernel_version}-coreos.tar"
