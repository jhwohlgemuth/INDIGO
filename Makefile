#!make
#
# .env is the single source of truth for the image reference, host publishing,
# and instance identity; the Makefile defines no fallbacks for those values.
# ENV_FILE selects an instance environment created by scripts/new.sh,
# for example: make up ENV_FILE=.env.two
ENV_FILE ?=
include .env
ifneq ($(ENV_FILE),)
include $(ENV_FILE)
endif

.PHONY: prepare format check check-env lint build push compose-build up down restart logs ps filesystem rust instance start run stop rm exec

COMPOSE ?= docker compose
COMPOSE_ARGS ?= -f ./compose.yaml $(if $(ENV_FILE),--env-file $(ENV_FILE),)
DOCKER_FILES := ./Dockerfile $(wildcard ./containers/*/Dockerfile)
SHELL_FILES := $(wildcard ./scripts/*.sh) $(wildcard ./rootfs/etc/cont-init.d/*) $(wildcard ./rootfs/etc/services.d/*/*) $(wildcard ./rootfs/opt/*/bin/*)
YAML_FILES := $(wildcard ./config/*/*.yaml) $(wildcard ./.github/workflows/*.yml ./.github/workflows/*.yaml) ./compose.yaml
FORMAT_FILES := ./.shellcheckrc $(SHELL_FILES) $(YAML_FILES)

CONTAINER ?= $(INDIGO_HOSTNAME)
IMAGE_REF ?= ${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}
INDIGO_HOME ?= /home/nonroot

prepare: format lint check

format:
	@dos2unix --quiet $(FORMAT_FILES)
	@shfmt --write $(SHELL_FILES)

check:
	@shfmt --diff $(SHELL_FILES)
	@shellcheck $(SHELL_FILES)
	@./scripts/check.sh $(ENV_FILE)

check-env:
	@./scripts/check.sh $(ENV_FILE)

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

instance:
	@./scripts/new.sh $(NAME) $(OFFSET) $(FORCE)

# Start the published image with nothing configured: no published ports, no
# volumes, no .env edits. The image's own defaults apply and the services are
# reachable inside the container only. Use run for host publishing.
start:
	@docker run \
		--detach \
		--interactive \
		--tty \
		--name "$(CONTAINER)" \
		--hostname "$(CONTAINER)" \
		--gpus all \
		--restart unless-stopped \
		--shm-size "$(INDIGO_SHM_SIZE)" \
		"$(IMAGE_REF)"

# Run the published image without Compose or this repository, publishing the
# ports and mounting the volumes declared in .env. --interactive and --tty are
# required: the image's default command is an interactive zsh, which exits at
# once without a TTY and turns the container into a restart loop.
run:
	@docker run \
		--detach \
		--interactive \
		--tty \
		--name "$(CONTAINER)" \
		--hostname "$(CONTAINER)" \
		--gpus all \
		--restart unless-stopped \
		--shm-size "$(INDIGO_SHM_SIZE)" \
		--publish "$(INDIGO_PUBLISH_HOST):$(INFERENCE_PUBLISHED_PORT):10732" \
		--publish "$(INDIGO_PUBLISH_HOST):$(CODE_SERVER_PUBLISHED_PORT):1337" \
		--publish "$(INDIGO_PUBLISH_HOST):$(VERDACCIO_PUBLISHED_PORT):4873" \
		--publish "$(INDIGO_PUBLISH_HOST):$(JUPYTER_PUBLISHED_PORT):13337" \
		--publish "$(INDIGO_PUBLISH_HOST):$(MARIMO_PUBLISHED_PORT):13338" \
		--publish "$(INDIGO_PUBLISH_HOST):$(OPENVIKING_PUBLISHED_PORT):1933" \
		--publish "$(INDIGO_PUBLISH_HOST):$(PINOKIO_PUBLISHED_PORT):42000" \
		--publish "$(INDIGO_PUBLISH_HOST):$(PINOKIO_PROXY_PUBLISHED_PORT):8080" \
		--publish "$(INDIGO_PUBLISH_HOST):$(MCP_FILESYSTEM_PUBLISHED_PORT):11002" \
		--publish "$(INDIGO_PUBLISH_HOST):$(MCP_RUST_ANALYZER_PUBLISHED_PORT):11003" \
		--volume "$(CONTAINER)-workspace:$(INDIGO_HOME)/dev" \
		--volume "$(CONTAINER)-models:$(INDIGO_HOME)/.models" \
		--volume "$(CONTAINER)-openviking:$(INDIGO_HOME)/.openviking" \
		--volume "$(CONTAINER)-pinokio:$(INDIGO_HOME)/.pinokio" \
		--volume "$(CONTAINER)-opencode-config:$(INDIGO_HOME)/.config/opencode" \
		--volume "$(CONTAINER)-opencode-data:$(INDIGO_HOME)/.local/share/opencode" \
		--volume "$(CONTAINER)-codex:$(INDIGO_HOME)/.codex" \
		--volume "$(CONTAINER)-cargo-cache:$(INDIGO_HOME)/.cargo" \
		"$(IMAGE_REF)"

stop:
	@docker stop "$(CONTAINER)"

rm: stop
	@docker rm "$(CONTAINER)"

exec:
	@$(COMPOSE) $(COMPOSE_ARGS) exec indigo $(CMD)

build:
	@docker build \
		--build-arg NOTEBOOK_VERSION="${NOTEBOOK_VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}" \
		--tag "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest" \
		.

push:
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}"
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest"
