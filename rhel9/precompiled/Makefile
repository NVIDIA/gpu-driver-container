RHEL_VERSION ?= 9.4
RHEL_VERSION_MAJOR = $(shell echo "${RHEL_VERSION}" | awk -F. '{print $$1}')

KERNEL_VERSION ?= ''
BUILD_ARCH ?= x86_64
TARGET_ARCH ?= $(shell echo "${BUILD_ARCH}" | sed "s/+64k//")

KERNEL_VERSION_NOARCH=$(shell echo "${KERNEL_VERSION}" | sed "s/\.${TARGET_ARCH}//")
KERNEL_VERSION_TAG = $(shell echo "${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}" | sed "s/+/_/")
BASE_URL ?= https://us.download.nvidia.com/tesla

CUDA_VERSION ?= 12.8.1
CUDA_DIST = ubi${RHEL_VERSION_MAJOR}

DRIVER_VERSION ?= ''
DRIVER_TYPE ?= passthrough
DRIVER_OPEN ?= false
DRIVER_STREAM_TYPE ?= ''

CONTAINER_TOOL ?= docker
DOCKERFILE ?= Dockerfile

IMAGE_REGISTRY ?= nvcr.io/ea-cnt/nv_only
ifeq ($(DRIVER_TYPE),vgpu)
	IMAGE_NAME ?= vgpu-guest-driver
else
	IMAGE_NAME ?= driver
endif

BUILDER_USER ?= $(shell git config --get user.name)
BUILDER_EMAIL ?= $(shell git config --get user.email)

# Red Hat subscription
RHSM_ORG_FILE ?= ${HOME}/.rhsm_org
RHSM_ACTIVATIONKEY_FILE ?= ${HOME}/.rhsm_activationkey

.PHONY: image image-push rhsm-register

# Build the image
image: rhsm-register
	@echo "!=== Building image ${IMAGE_REGISTRY}/${IMAGE_NAME}:${DRIVER_VERSION}-${KERNEL_VERSION_TAG}-${OS_TAG} ===!"
	@if [ "${CONTAINER_TOOL}" == "docker" ]; then \
		echo "!=== Work around accessing DTK image using a pull secret with Docker ===!" \
		&& mkdir -p .tmp && cp ${PULL_SECRET_FILE} .tmp/config.json \
		&& ${CONTAINER_TOOL} --config .tmp pull ${DRIVER_TOOLKIT_IMAGE} \
		&& rm ./.tmp/config.json \
		&& BUILD_CMD_ADD_ARGS=; \
	else \
		BUILD_CMD_ADD_ARGS="--authfile ${PULL_SECRET_FILE}"; \
	fi \
	&& ${CONTAINER_TOOL} build \
		$${BUILD_CMD_ADD_ARGS} \
		--secret id=RHSM_ORG,src=${RHSM_ORG_FILE} \
		--secret id=RHSM_ACTIVATIONKEY,src=${RHSM_ACTIVATIONKEY_FILE} \
		--build-arg RHEL_VERSION=${RHEL_VERSION} \
		--build-arg RHEL_VERSION_MAJOR=${RHEL_VERSION_MAJOR} \
		--build-arg CUDA_VERSION=${CUDA_VERSION} \
		--build-arg CUDA_DIST=${CUDA_DIST} \
		--build-arg BUILD_ARCH=${BUILD_ARCH} \
		--build-arg TARGET_ARCH=${TARGET_ARCH} \
		--build-arg KERNEL_VERSION=${KERNEL_VERSION} \
		--build-arg KERNEL_VERSION_NOARCH=${KERNEL_VERSION_NOARCH} \
		--build-arg DRIVER_VERSION=${DRIVER_VERSION} \
		--build-arg DRIVER_EPOCH=${DRIVER_EPOCH} \
		--build-arg BUILDER_USER="${BUILDER_USER}" \
		--build-arg BUILDER_EMAIL=${BUILDER_EMAIL} \
		--build-arg DRIVER_TOOLKIT_IMAGE=${DRIVER_TOOLKIT_IMAGE} \
		--build-arg DRIVER_OPEN=${DRIVER_OPEN} \
        --build-arg DRIVER_TYPE=${DRIVER_TYPE} \
		--build-arg DRIVER_STREAM_TYPE=${DRIVER_STREAM_TYPE} \
		--build-arg BASE_URL=${BASE_URL} \
		--build-arg OS_TAG=${OS_TAG} \
		--tag ${IMAGE_REGISTRY}/${IMAGE_NAME}:${DRIVER_VERSION}-${KERNEL_VERSION_TAG}-${OS_TAG} \
		--progress=plain \
		--file ${DOCKERFILE} .

image-push:
	@echo "!=== Pushing image ===!"
	${CONTAINER_TOOL} push \
		${IMAGE_REGISTRY}/${IMAGE_NAME}:${DRIVER_VERSION}-${KERNEL_VERSION_TAG}-${OS_TAG}

