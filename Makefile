.PHONY: all build local push push-short push-latest

SHELL := /bin/bash

ifeq ($(IMAGE),)
export IMAGE := nvidia/driver
endif
VERSION ?= "460.73.01"

CI_COMMIT_TAG := "$(shell git describe --abbrev=0 --tags)"

all: build

# Build default version(s)
build: $(patsubst %,driver-%,$(VERSION))

# Building multiple versions through TF
driver-%:
	IMAGE="$(IMAGE)" VERSION="$*" ./ci/build.sh

# Local building of a single version
local-%:
	CI_COMMIT_TAG="${CI_COMMIT_TAG}" FORCE=true REGISTRY="${IMAGE}" DRIVER_VERSION="$(firstword ${VERSION})" ./ci/$*/build.sh "$(firstword $(VERSION))" "$(CI_COMMIT_TAG)" "$(IMAGE)"

local: local-flatcar local-coreos

push:
	true

push-short:
	true

push-latest:
	true
