#!make
include .env

.PHONY: prepare format check lint build push compose-build up down restart logs ps filesystem rust

IMAGE ?= indigo
COMPOSE ?= docker compose
COMPOSE_ARGS ?= -f ./compose.yaml
DOCKER_FILES := ./Dockerfile $(wildcard ./containers/*/Dockerfile)
SHELL_FILES := $(wildcard ./scripts/*.sh) $(wildcard ./rootfs/etc/cont-init.d/*) $(wildcard ./rootfs/etc/services.d/*/*) $(wildcard ./rootfs/opt/*/bin/*)
YAML_FILES := $(wildcard ./config/*/*.yaml) $(wildcard ./.github/workflows/*.yml ./.github/workflows/*.yaml) ./compose.yaml
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
	@yamllint ./config ./rootfs ./.github ./compose.yaml
	@$(COMPOSE) $(COMPOSE_ARGS) config --quiet

compose-build:
	@$(COMPOSE) $(COMPOSE_ARGS) build

up:
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach

down:
	@$(COMPOSE) $(COMPOSE_ARGS) down

restart:
	@$(COMPOSE) $(COMPOSE_ARGS) restart

logs:
	@$(COMPOSE) $(COMPOSE_ARGS) logs --follow

ps:
	@$(COMPOSE) $(COMPOSE_ARGS) ps

filesystem:
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach --build indigo

rust:
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach --build indigo

build:
	@docker build \
		--build-arg NOTEBOOK_VERSION="${NOTEBOOK_VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest" \
		.

push:
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}"
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest"
