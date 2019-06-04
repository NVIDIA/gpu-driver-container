#!/bin/bash

CI_PROJECT_NAMESPACE="nvidia"
CI_PROJECT_NAME="driver"
REPOSITORY="${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}"
DRIVER_VERSION="418.67"
OS="coreos"
COREOS_RELEASE_CHANNEL="stable"
COREOS_RELEASES_URL="https://coreos.com/releases/releases-${COREOS_RELEASE_CHANNEL}.json"
COREOS_SOFTWARE_VERSIONS="$(curl -Ls ${COREOS_RELEASES_URL} | jq -r 'keys_unsorted[0] as $k | .[$k] | "\(.major_software.kernel[0]) \(.major_software.docker[0])"')"
KERNEL_VERSION="$(echo ${COREOS_SOFTWARE_VERSIONS} | awk '{ print $1 }')-${OS}"
#COREOS_DOCKER_VERSION="$(echo ${COREOS_SOFTWARE_VERSIONS} | awk '{ print $2 }')"

docker build -t "install-${CI_PROJECT_NAME}:${DRIVER_VERSION}" --build-arg DRIVER_VERSION=${DRIVER_VERSION} .

docker run --privileged --name "compile_${CI_PROJECT_NAME}-${DRIVER_VERSION}" "install-${CI_PROJECT_NAME}:${DRIVER_VERSION}" update --kernel ${KERNEL_VERSION}

docker commit -m "Compile Linux kernel modules version ${KERNEL_VERSION} for NVIDIA driver version ${DRIVER_VERSION}" --change='ENTRYPOINT ["nvidia-driver", "init"]' "compile_${CI_PROJECT_NAME}-${DRIVER_VERSION}" "${REPOSITORY}:${DRIVER_VERSION}-${KERNEL_VERSION}"

docker tag "${REPOSITORY}:${DRIVER_VERSION}-${KERNEL_VERSION}" "${REPOSITORY}:${DRIVER_VERSION}-${OS}"

docker rm "compile_${CI_PROJECT_NAME}-${DRIVER_VERSION}"
docker rmi "install-${CI_PROJECT_NAME}:${DRIVER_VERSION}"
