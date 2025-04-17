DOCKERFILE = Dockerfile
RHEL_VERSION ?= 8.6
CUDA_VERSION ?= 12.6.0
CUDA_DIST ?= ubi8
DRIVER_VERSION ?= 535.247.01
KERNEL_VERSION ?= 4.18.0-372.51.1.el8_6.x86_64
TARGET_ARCH = $(shell echo "${KERNEL_VERSION}" | awk -F. '{print $$NF}')
CONTAINER_TOOL ?= docker
IMAGE_REGISTRY ?= nvcr.io/ea-cnt/nv_only
BASE_URL ?= https://us.download.nvidia.com/tesla
DRIVER_TYPE ?= passthrough
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
	@echo "!=== Building image ===!"
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
		--build-arg CUDA_VERSION=${CUDA_VERSION} \
		--build-arg CUDA_DIST=${CUDA_DIST} \
		--build-arg TARGET_ARCH=${TARGET_ARCH} \
		--build-arg KERNEL_VERSION=${KERNEL_VERSION} \
		--build-arg DRIVER_VERSION=${DRIVER_VERSION} \
		--build-arg DRIVER_EPOCH=${DRIVER_EPOCH} \
		--build-arg BUILDER_USER="${BUILDER_USER}" \
		--build-arg BUILDER_EMAIL=${BUILDER_EMAIL} \
		--build-arg DRIVER_TOOLKIT_IMAGE=${DRIVER_TOOLKIT_IMAGE} \
		--build-arg DRIVER_TYPE=${DRIVER_TYPE} \
		--build-arg BASE_URL=${BASE_URL} \
		--tag ${IMAGE_REGISTRY}/${IMAGE_NAME}:${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG} \
		--progress=plain \
		--file ${DOCKERFILE} .

image-push:
	@echo "!=== Pushing image ===!"
	${CONTAINER_TOOL} push \
	${IMAGE_REGISTRY}/${IMAGE_NAME}:${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG}
