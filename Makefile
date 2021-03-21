.PHONY: all build build-local push push-short push-latest

SHELL := /bin/bash

ifeq ($(IMAGE),)
export IMAGE := nvidia/driver
endif
export VERSION ?= "440.64.00"

CI_COMMIT_TAG := "$(shell git describe --abbrev=0 --tags)"

all: build

# Building through TF
build:
	IMAGE="$(IMAGE)" VERSION="$(VERSION)" ./ci/build.sh

# Local building
local-%:
	CI_COMMIT_TAG="${CI_COMMIT_TAG}" FORCE=true REGISTRY="${IMAGE}" DRIVER_VERSION="${VERSION}" ./ci/$*/build.sh "$(VERSION)" "$(CI_COMMIT_TAG)" "$(IMAGE)"

build-local: build-flatcar build-coreos

push:
	true

push-short:
	true

push-latest:
	true
