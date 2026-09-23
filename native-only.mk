# Copyright (c) 2022, NVIDIA CORPORATION.  All rights reserved.
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

PUSH_ON_BUILD ?= false
DOCKER_BUILD_OPTIONS ?= --output=type=image,push=$(PUSH_ON_BUILD)
HOST_ARCH ?= $(shell uname -m)
NATIVE_ARCH ?= $(if $(filter x86_64 amd64,$(HOST_ARCH)),amd64,$(if $(filter aarch64 arm64,$(HOST_ARCH)),arm64,$(HOST_ARCH)))
DOCKER_BUILD_PLATFORM_OPTIONS ?= --platform=linux/$(NATIVE_ARCH)

$(DRIVER_PUSH_TARGETS): push-%:
	$(DOCKER) tag "$(IMAGE)" "$(OUT_IMAGE)"
	$(DOCKER) push "$(OUT_IMAGE)"

$(VGPU_GUEST_DRIVER_PUSH_TARGETS): push-vgpuguest-%:
	$(DOCKER) tag "$(IMAGE)" "$(OUT_IMAGE)"
	$(DOCKER) push "$(OUT_IMAGE)"

$(VGPU_HOST_DRIVER_PUSH_TARGETS): push-vgpuhost-%:
	$(DOCKER) tag "$(IMAGE)" "$(OUT_IMAGE)"
	$(DOCKER) push "$(OUT_IMAGE)"
