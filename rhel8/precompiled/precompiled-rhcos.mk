# current dir 
CURDIR=$(shell pwd)

DOCKERFILE = Dockerfile
RHEL_VERSION ?= 8.6
CUDA_VERSION ?= 11.8.0
DRIVER_BRANCH ?= 515
KERNEL_VERSION ?= 4.18.0-372.32.1.el8_6
IMAGE_BUILD_CMD ?= docker build
IMAGE_REGISTRY ?= nvcr.io/ea-cnt/nv_only

# RedHat Bits
RHSM_ORG ?=<SECRET>
RHSM_ACTIVATIONKEY?=<SECRET>
PULL_SECRET_FILE?=<SECRET>

# Build the image
image: rhsm-register
	@echo "!===	Building image	===!"
	${IMAGE_BUILD_CMD} --build-arg RHEL_VERSION=${RHEL_VERSION} \
	--build-arg CUDA_VERSION=${CUDA_VERSION} \
	--build-arg KERNEL_VERSION=${KERNEL_VERSION} \
	--build-arg DRIVER_BRANCH=${DRIVER_BRANCH} \
	--tag ${IMAGE_REGISTRY}/driver-toolkit:${RHEL_VERSION}-${KERNEL_VERSION} \
	--file ${DOCKERFILE} .

rhsm-register:
	@rm -f rhsm-register
	@echo "!===	Generating rhsm-register	===!"
	@echo "#!/bin/bash" > rhsm-register
	@echo "" >> rhsm-register
	@echo "subscription-manager register --name=driver-toolkit-builder --org=${RHSM_ORG} --activationkey=${RHSM_ACTIVATIONKEY}" >> rhsm-register
	@chmod +x rhsm-register

build-matrix:
	@echo "!===	Building build-matrix	===!"
	./build-matrix.sh ${PULL_SECRET_FILE}