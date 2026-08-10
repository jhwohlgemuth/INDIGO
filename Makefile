#!make
include .env

.PHONY: prepare check lint build push

IMAGE ?= goldsmith
SHELL_FILES := $(wildcard ./scripts/*.sh) $(wildcard ./rootfs/etc/services.d/inference-router/*)

prepare: lint check

check:
	@shfmt --diff $(SHELL_FILES)
	@shellcheck $(SHELL_FILES)

lint:
	@hadolint ./Dockerfile
	@yamllint ./config ./rootfs ./.github

build:
	@docker build \
		--build-arg NOTEBOOK_VERSION="${NOTEBOOK_VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest" \
		.

push:
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}"
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest"
