.PHONY: all

SHELL := /bin/bash

ifeq ($(IMAGE),)
export IMAGE := nvidia/driver
endif
export VERSION ?= "440.64.00"


all: build

build:
	IMAGE="$(IMAGE)" VERSION="$(VERSION)" ./ci/build.sh

push:
	true

push-short:
	true

push-latest:
	true
