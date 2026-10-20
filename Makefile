#!make
include .env

.PHONY: prepare format check lint build image-smoke push compose-build up up-cpu up-isolated down restart logs ps filesystem rust

IMAGE ?= indigo
COMPOSE ?= docker compose
COMPOSE_ARGS ?= -f ./compose.yaml
DOCKER_FILES := ./Dockerfile $(wildcard ./containers/*/Dockerfile)
SHELL_FILES := $(wildcard ./scripts/*.sh) $(wildcard ./rootfs/etc/cont-init.d/*) $(wildcard ./rootfs/etc/services.d/*/*) $(wildcard ./rootfs/opt/*/bin/*)
YAML_FILES := $(wildcard ./config/*/*.yaml) $(wildcard ./.github/workflows/*.yml ./.github/workflows/*.yaml) $(wildcard ./compose*.yaml)
FORMAT_FILES := ./.shellcheckrc $(SHELL_FILES) $(YAML_FILES)

prepare: format lint check

format:
	@dos2unix --quiet $(FORMAT_FILES)
	@shfmt --write $(SHELL_FILES)

check:
	@shfmt --diff $(SHELL_FILES)
	@shellcheck $(SHELL_FILES)

lint:
	@hadolint $(DOCKER_FILES)
	@yamllint $(YAML_FILES)
	@$(COMPOSE) $(COMPOSE_ARGS) config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.cpu.yaml config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.isolated.yaml config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.cpu.yaml -f ./compose.isolated.yaml config --quiet

compose-build:
	@$(COMPOSE) $(COMPOSE_ARGS) build

up:
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach

up-cpu:
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.cpu.yaml up --detach

up-isolated:
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.isolated.yaml up --detach

down:
	@$(COMPOSE) $(COMPOSE_ARGS) down

restart:
	@$(COMPOSE) $(COMPOSE_ARGS) restart

logs:
	@$(COMPOSE) $(COMPOSE_ARGS) logs --follow

ps:
	@$(COMPOSE) $(COMPOSE_ARGS) ps

filesystem:
	@echo "Filesystem MCP is part of the full Indigo stack; starting Indigo."
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach --build indigo

rust:
	@echo "Rust Analyzer MCP is part of the full Indigo stack; starting Indigo."
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach --build indigo

build:
	@docker build \
		--build-arg NOTEBOOK_VERSION="${NOTEBOOK_VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest" \
		.

image-smoke:
	@docker run --rm --entrypoint /bin/bash "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}" \
		-lc 'test -x /healthcheck && command -v llama-swap && command -v llama-server && test -r /etc/indigo/defaults/llama-swap.yaml'

push:
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}"
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest"
