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

# VERSION indicates the version to tag the image with.
# Production tags should be in the form <driver-version>-<dist>
# Development tags should be in the form <commit-sha>-<driver-version>-<dist>
ifeq ($(VERSION),)
IMAGE_VERSION = $(DRIVER_VERSION)
else
IMAGE_VERSION = $(VERSION)-$(DRIVER_VERSION)
endif

IMAGE_TAG = $(IMAGE_VERSION)-$(DIST)
IMAGE = $(IMAGE_NAME):$(IMAGE_TAG)

OUT_IMAGE_NAME ?= $(IMAGE_NAME)

ifeq ($(OUT_VERSION),)
OUT_IMAGE_VERSION = $(DRIVER_VERSION)
else
OUT_IMAGE_VERSION = $(OUT_VERSION)-$(DRIVER_VERSION)
endif

OUT_IMAGE_TAG = $(OUT_IMAGE_VERSION)-$(DIST)
OUT_IMAGE = $(OUT_IMAGE_NAME):$(OUT_IMAGE_TAG)

##### Public rules #####
DISTRIBUTIONS := ubuntu18.04 ubuntu20.04 rhcos4.9 rhcos4.10 centos7 flatcar

PUSH_TARGETS := $(patsubst %, push-%, $(DISTRIBUTIONS))
DRIVER_PUSH_TARGETS := $(foreach push_target, $(PUSH_TARGETS), $(addprefix $(push_target)-, $(DRIVER_VERSIONS)))
BUILD_TARGETS := $(patsubst %, build-%, $(DISTRIBUTIONS))
DRIVER_BUILD_TARGETS := $(foreach build_target, $(BUILD_TARGETS), $(addprefix $(build_target)-, $(DRIVER_VERSIONS)))
TEST_TARGETS := $(patsubst %, build-%, $(DISTRIBUTIONS))

PHONY: $(DISTRIBUTIONS) $(PUSH_TARGETS) $(BUILD_TARGETS) $(TEST_TARGETS) $(DRIVER_BUILD_TARGETS)

ifeq ($(BUILD_MULTI_ARCH_IMAGES),true)
include $(CURDIR)/multi-arch.mk
else
include $(CURDIR)/native-only.mk
endif

# $(DRIVER_PUSH_TARGETS) is in the form of push-$(DIST)-$(DRIVER_VERSION)
# Parse the target to set the required variables.
push-%: DIST = $(word 2,$(subst -, ,$@))
push-%: DRIVER_VERSION = $(word 3,$(subst -, ,$@))

# push-ubuntu20.04 pushes all driver images for ubuntu20.04
# push-ubuntu20.04-$(DRIVER_VERSION) pushes an image for the specific $(DRIVER_VERSION)
$(PUSH_TARGETS): %: $(foreach driver_version, $(DRIVER_VERSIONS), $(addprefix %-, $(driver_version)))


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
				--build-arg DRIVER_BRANCH="$(DRIVER_BRANCH)" \
				--build-arg CUDA_VERSION="$(CUDA_VERSION)" \
				--build-arg CVE_UPDATES="$(CVE_UPDATES)" \
				--file $(DOCKERFILE) \
				$(CURDIR)/$(SUBDIR)

# Files for rhcos are in the rhel8 subdirectory
build-rhcos%: SUBDIR = rhel8
