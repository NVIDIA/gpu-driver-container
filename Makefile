# Copyright (c) 2021-2022, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BUILD_MULTI_ARCH_IMAGES ?= no
DOCKER ?= docker
BUILDX =
ifeq ($(BUILD_MULTI_ARCH_IMAGES), true)
BUILDX = buildx
endif

##### Global variables #####
include $(CURDIR)/versions.mk

ifeq ($(IMAGE_NAME),)
REGISTRY ?= nvidia
IMAGE_NAME := $(REGISTRY)/driver
endif

DRIVER_TAG = $(DRIVER_VERSION)

# VERSION indicates the version to tag the image with.
# Production tags should be in the form <driver-version>-<dist>
# Development tags should be in the form <commit-sha>-<driver-version>-<dist>
ifeq ($(VERSION),)
IMAGE_VERSION = $(DRIVER_TAG)
else
IMAGE_VERSION = $(VERSION)-$(DRIVER_TAG)
endif

IMAGE_TAG = $(IMAGE_VERSION)-$(DIST)
IMAGE = $(IMAGE_NAME):$(IMAGE_TAG)

OUT_IMAGE_NAME ?= $(IMAGE_NAME)

ifeq ($(OUT_VERSION),)
OUT_IMAGE_VERSION = $(DRIVER_TAG)
else
OUT_IMAGE_VERSION = $(OUT_VERSION)-$(DRIVER_TAG)
endif

OUT_DIST ?= $(DIST)
OUT_IMAGE_TAG = $(OUT_IMAGE_VERSION)-$(OUT_DIST)
OUT_IMAGE = $(OUT_IMAGE_NAME):$(OUT_IMAGE_TAG)

##### Public rules #####
DISTRIBUTIONS := ubuntu18.04 ubuntu20.04 ubuntu22.04 ubuntu24.04 signed_ubuntu20.04 signed_ubuntu22.04 signed_ubuntu24.04 rhel8 rhel9 flatcar fedora36 sles15.3 precompiled_rhcos
PUSH_TARGETS := $(patsubst %, push-%, $(DISTRIBUTIONS))
BASE_FROM := noble jammy focal
PUSH_TARGETS := $(patsubst %, push-%, $(DISTRIBUTIONS))
VGPU_GUEST_DRIVER_PUSH_TARGETS := $(patsubst %, push-vgpuguest-%, $(DISTRIBUTIONS))
DRIVER_PUSH_TARGETS := $(foreach push_target, $(PUSH_TARGETS), $(addprefix $(push_target)-, $(DRIVER_VERSIONS)))
BUILD_TARGETS := $(patsubst %, build-%, $(DISTRIBUTIONS))
DRIVER_BUILD_TARGETS := $(foreach build_target, $(BUILD_TARGETS), $(addprefix $(build_target)-, $(DRIVER_VERSIONS)))
VGPU_GUEST_DRIVER_BUILD_TARGETS := $(patsubst %, build-vgpuguest-%, $(DISTRIBUTIONS))
TEST_TARGETS := $(patsubst %, test-%, $(DISTRIBUTIONS))
PULL_TARGETS := $(patsubst %, pull-%, $(DISTRIBUTIONS))
DRIVER_PULL_TARGETS := $(foreach pull_target, $(PULL_TARGETS), $(addprefix $(pull_target)-, $(DRIVER_VERSIONS)))
ARCHIVE_TARGETS := $(patsubst %, archive-%, $(DISTRIBUTIONS))
DRIVER_ARCHIVE_TARGETS := $(foreach archive_target, $(ARCHIVE_TARGETS), $(addprefix $(archive_target)-, $(DRIVER_VERSIONS)))
BASE_BUILD := $(patsubst %, build-base-%, $(BASE_FROM))
BASE_PUSH := $(patsubst %, push-base-%, $(BASE_FROM))
BASE_BUILD_TARGETS := $(foreach target,$(BASE_BUILD),$(target))
BASE_PUSH_TARGETS := $(foreach target,$(BASE_PUSH),$(target))

PHONY: $(BASE_BUILD_TARGETS) $(BASE_PUSH_TARGETS) $(DISTRIBUTIONS) $(PUSH_TARGETS) $(BUILD_TARGETS) $(TEST_TARGETS) $(PULL_TARGETS) $(ARCHIVE_TARGETS) $(DRIVER_PUSH_TARGETS) $(DRIVER_BUILD_TARGETS) $(DRIVER_PULL_TARGETS) $(DRIVER_ARCHIVE_TARGETS) $(VGPU_GUEST_DRIVER_BUILD_TARGETS) $(VGPU_GUEST_DRIVER_PUSH_TARGETS)

ifeq ($(BUILD_MULTI_ARCH_IMAGES),true)
include $(CURDIR)/multi-arch.mk
else
include $(CURDIR)/native-only.mk
endif

pull-%: DIST = $(word 2,$(subst -, ,$@))
pull-%: DRIVER_VERSION = $(word 3,$(subst -, ,$@))
pull-%: DRIVER_BRANCH = $(word 1,$(subst ., ,${DRIVER_VERSION}))

$(PULL_TARGETS): %: $(foreach driver_version, $(DRIVER_VERSIONS), $(addprefix %-, $(driver_version)))

pull-signed_ubuntu20.04%: DIST = signed-ubuntu20.04
pull-signed_ubuntu20.04%: DRIVER_TAG = $(DRIVER_BRANCH)

pull-signed_ubuntu22.04%: DIST = ubuntu22.04
pull-signed_ubuntu22.04%: DRIVER_TAG = $(DRIVER_BRANCH)
pull-signed_ubuntu22.04%: IMAGE_TAG = $(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)

pull-signed_ubuntu24.04%: DIST = ubuntu24.04
pull-signed_ubuntu24.04%: DRIVER_TAG = $(DRIVER_BRANCH)
pull-signed_ubuntu24.04%: IMAGE_TAG = $(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)

PLATFORM ?= linux/amd64
$(DRIVER_PULL_TARGETS): pull-%:
	$(DOCKER) pull "--platform=$(PLATFORM)" "$(IMAGE)"

archive-%: DIST = $(word 2,$(subst -, ,$@))
archive-%: DRIVER_VERSION = $(word 3,$(subst -, ,$@))
archive-%: DRIVER_BRANCH = $(word 1,$(subst ., ,${DRIVER_VERSION}))

$(ARCHIVE_TARGETS): %: $(foreach driver_version, $(DRIVER_VERSIONS), $(addprefix %-, $(driver_version)))

archive-signed_ubuntu20.04%: DIST = signed-ubuntu20.04
archive-signed_ubuntu20.04%: DRIVER_TAG = $(DRIVER_BRANCH)

archive-signed_ubuntu22.04%: DIST = ubuntu22.04
archive-signed_ubuntu22.04%: DRIVER_TAG = $(DRIVER_BRANCH)
archive-signed_ubuntu22.04%: IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)

archive-signed_ubuntu24.04%: DIST = ubuntu24.04
archive-signed_ubuntu24.04%: DRIVER_TAG = $(DRIVER_BRANCH)
archive-signed_ubuntu24.04%: IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)

$(DRIVER_ARCHIVE_TARGETS): archive-%:
	$(DOCKER) save "$(IMAGE)" -o "archive.tar"

# $(DRIVER_PUSH_TARGETS) is in the form of push-$(DIST)-$(DRIVER_VERSION)
# Parse the target to set the required variables.
push-%: DIST = $(word 2,$(subst -, ,$@))
push-%: DRIVER_VERSION = $(word 3,$(subst -, ,$@))
push-%: DRIVER_BRANCH = $(word 1,$(subst ., ,${DRIVER_VERSION}))

# push-ubuntu20.04 pushes all driver images for ubuntu20.04
# push-ubuntu20.04-$(DRIVER_VERSION) pushes an image for the specific $(DRIVER_VERSION)
$(PUSH_TARGETS): %: $(foreach driver_version, $(DRIVER_VERSIONS), $(addprefix %-, $(driver_version)))

push-signed_ubuntu20.04%: DIST = signed-ubuntu20.04
push-signed_ubuntu20.04%: DRIVER_TAG = $(DRIVER_BRANCH)

push-signed_ubuntu22.04%: DIST = ubuntu22.04
push-signed_ubuntu22.04%: DRIVER_TAG = $(DRIVER_BRANCH)
push-signed_ubuntu22.04%: IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)
push-signed_ubuntu22.04%: OUT_IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)

push-signed_ubuntu24.04%: DIST = ubuntu24.04
push-signed_ubuntu24.04%: DRIVER_TAG = $(DRIVER_BRANCH)
push-signed_ubuntu24.04%: IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)
push-signed_ubuntu24.04%: OUT_IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)

# $(DRIVER_BUILD_TARGETS) is in the form of build-$(DIST)-$(DRIVER_VERSION)
# Parse the target to set the required variables.
build-%: DIST = $(word 2,$(subst -, ,$@))
build-%: DRIVER_VERSION = $(word 3,$(subst -, ,$@))
build-%: DRIVER_BRANCH = $(word 1,$(subst ., ,${DRIVER_VERSION}))
build-%: SUBDIR = $(word 2,$(subst -, ,$@))
build-%: DOCKERFILE = $(CURDIR)/$(SUBDIR)/Dockerfile

# Both ubuntu20.04 and build-ubuntu20.04 trigger a build of all driver images for ubuntu20.04
# build-ubuntu20.04-$(DRIVER_VERSION) triggers a build for a specific $(DRIVER_VERSION)
$(DISTRIBUTIONS): %: build-%
$(BUILD_TARGETS): %: $(foreach driver_version, $(DRIVER_VERSIONS), $(addprefix %-, $(driver_version)))
$(DRIVER_BUILD_TARGETS):
	DOCKER_BUILDKIT=1 \
		$(DOCKER) $(BUILDX) build --pull \
				$(DOCKER_BUILD_OPTIONS) \
				$(DOCKER_BUILD_PLATFORM_OPTIONS) \
				--tag $(IMAGE) \
				--build-arg DRIVER_VERSION="$(DRIVER_VERSION)" \
				--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
				--build-arg DRIVER_BRANCH="$(DRIVER_BRANCH)" \
				--build-arg CUDA_VERSION="$(CUDA_VERSION)" \
				--build-arg CVE_UPDATES="$(CVE_UPDATES)" \
				$(DOCKER_BUILD_ARGS) \
				--file $(DOCKERFILE) \
				$(CURDIR)/$(SUBDIR)

build-rhcos%: SUBDIR = rhel8

build-fedora%: SUBDIR = fedora

build-sles15%: SUBDIR = sle15
build-sles%: DOCKER_BUILD_ARGS = --build-arg SLES_VERSION=$(subst sles,,$(word 2,$(subst -, ,$@)))

# ubuntu20.04 Precompiled Driver
build-signed_ubuntu20.04%: DIST = signed-ubuntu20.04
build-signed_ubuntu20.04%: SUBDIR = ubuntu20.04/precompiled
build-signed_ubuntu20.04%: DRIVER_TAG = $(DRIVER_BRANCH)

# ubuntu22.04 Precompiled Driver
build-signed_ubuntu22.04%: DIST = ubuntu22.04
build-signed_ubuntu22.04%: SUBDIR = ubuntu22.04/precompiled
build-signed_ubuntu22.04%: DRIVER_TAG = $(DRIVER_BRANCH)
build-signed_ubuntu22.04%: IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)
build-signed_ubuntu22.04%: DOCKER_BUILD_ARGS =  --build-arg KERNEL_VERSION="$(KERNEL_VERSION)"

# ubuntu24.04 Precompiled Driver
build-signed_ubuntu24.04%: DIST = ubuntu24.04
build-signed_ubuntu24.04%: SUBDIR = ubuntu24.04/precompiled
build-signed_ubuntu24.04%: DRIVER_TAG = $(DRIVER_BRANCH)
build-signed_ubuntu24.04%: IMAGE_TAG = $(if $(VERSION),$(VERSION)-)$(DRIVER_BRANCH)-$(KERNEL_VERSION)-$(DIST)
build-signed_ubuntu24.04%: DOCKER_BUILD_ARGS =  --build-arg KERNEL_VERSION="$(KERNEL_VERSION)"

# base is an image used to poll Canonical for the latest kernel version
# LTS_KERNEL must be defined in the environment when invoking this target.
LTS_KERNEL ?= ""
build-base-%: $(if $(LTS_KERNEL),,$(error "LTS_KERNEL is not set"))
build-base-%: DOCKERFILE = $(CURDIR)/base/Dockerfile
build-base-%: TARGET = $(word 3,$(subst -, ,$@))
build-base-%: IMAGE_TAG = base-$(word 3,$(subst -, ,$@))-$(LTS_KERNEL)-$(KERNEL_FLAVOR)-$(DRIVER_BRANCH)
$(BASE_BUILD_TARGETS):
	DOCKER_BUILDKIT=1 \
		$(DOCKER) $(BUILDX) build --pull --no-cache \
				$(DOCKER_BUILD_OPTIONS) \
				--tag $(IMAGE)  \
				--target $(TARGET) \
				--build-arg CUDA_VERSION="$(CUDA_VERSION)" \
				--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
				--build-arg DRIVER_BRANCH="$(DRIVER_BRANCH)" \
				--build-arg KERNEL_FLAVOR="$(KERNEL_FLAVOR)" \
				--build-arg LTS_KERNEL="$(LTS_KERNEL)" \
				--file $(DOCKERFILE) \
				$(CURDIR)/base

push-base-%: TARGET = $(word 3,$(subst -, ,$@))
push-base-%: IMAGE_TAG = base-$(word 3,$(subst -, ,$@))-$(LTS_KERNEL)-$(KERNEL_FLAVOR)-$(DRIVER_BRANCH)
push-base-%: OUT_IMAGE_TAG = ${IMAGE_TAG}
$(BASE_PUSH_TARGETS):
	regctl \
		image copy \
		$(IMAGE) $(OUT_IMAGE)

# $(VGPU_GUEST_DRIVER_BUILD_TARGETS) is in the form of build-vgpuguest-$(DIST)
# The vGPU guest driver .run file is assumed to be present in the $SUBDIR/drivers/ directory.
# VGPU_GUEST_DRIVER_VERSION must be defined in the environment when invoking this target.
VGPU_GUEST_DRIVER_VERSION ?= ""
build-vgpuguest-%: $(if $(VGPU_GUEST_DRIVER_VERSION),,$(error "VGPU_GUEST_DRIVER_VERSION is not set"))
# Ensure DRIVER_VERSION has the -grid suffix
build-vgpuguest-%: DRIVER_VERSION := $(addsuffix -grid,$(VGPU_GUEST_DRIVER_VERSION:-grid=))
build-vgpuguest-%: DRIVER_BRANCH = $(word 1,$(subst ., ,${DRIVER_VERSION}))
build-vgpuguest-%: DIST = $(word 3,$(subst -, ,$@))
build-vgpuguest-%: SUBDIR = $(word 3,$(subst -, ,$@))
build-vgpuguest-%: DOCKERFILE = $(CURDIR)/$(SUBDIR)/Dockerfile
# Remove '-grid' substring in the image tag
build-vgpuguest-%: DRIVER_TAG = $(DRIVER_VERSION:-grid=)

build-vgpuguest-rhcos%: SUBDIR = rhel8

$(VGPU_GUEST_DRIVER_BUILD_TARGETS):
	DOCKER_BUILDKIT=1 \
		$(DOCKER) $(BUILDX) build --pull \
				$(DOCKER_BUILD_OPTIONS) \
				$(DOCKER_BUILD_PLATFORM_OPTIONS) \
				--tag $(IMAGE) \
				--build-arg DRIVER_TYPE=vgpu \
				--build-arg VGPU_LICENSE_SERVER_TYPE=NLS \
				--build-arg DRIVER_VERSION="$(DRIVER_VERSION)" \
				--build-arg DRIVER_BRANCH="$(DRIVER_BRANCH)" \
				--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
				--build-arg CVE_UPDATES="$(CVE_UPDATES)" \
				$(DOCKER_BUILD_ARGS) \
				--file $(DOCKERFILE) \
				$(CURDIR)/$(SUBDIR)


# $(VGPU_GUEST_DRIVER_PUSH_TARGETS) is in the form of push-vgpuguest-$(DIST)
# VGPU_GUEST_DRIVER_VERSION must be defined in the environment when invoking this target.
push-vgpuguest-%: $(if $(VGPU_GUEST_DRIVER_VERSION),,$(error "VGPU_GUEST_DRIVER_VERSION is not set"))
# Remove '-grid' substring in the image tag
push-vgpuguest-%: DRIVER_TAG = $(VGPU_GUEST_DRIVER_VERSION:-grid=)
push-vgpuguest-%: DIST = $(word 3,$(subst -, ,$@))

