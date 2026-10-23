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

.PHONY: prepare format check check-env lint build image-smoke push compose-build up up-cpu up-isolated up-mlx down down-mlx mlx-setup mlx-model mlx-model-download mlx-model-check mlx-model-self-test mlx-status restart logs ps filesystem rust instance start run stop rm exec

COMPOSE ?= docker compose
YAMLLINT ?= yamllint
COMPOSE_ARGS ?= -f ./compose.yaml $(if $(ENV_FILE),--env-file $(ENV_FILE),)
DOCKER_FILES := ./Dockerfile $(wildcard ./containers/*/Dockerfile)
SHELL_FILES := $(wildcard ./scripts/*.sh) $(wildcard ./rootfs/etc/cont-init.d/*) $(wildcard ./rootfs/etc/services.d/*/*) $(wildcard ./rootfs/opt/*/bin/*) $(wildcard ./tests/*.sh)
TEST_FILES := $(wildcard ./tests/*.sh)
YAML_FILES := $(wildcard ./config/*/*.yaml) $(wildcard ./.github/workflows/*.yml ./.github/workflows/*.yaml) $(wildcard ./compose*.yaml)
FORMAT_FILES := ./.shellcheckrc $(SHELL_FILES) $(YAML_FILES)

CONTAINER ?= $(INDIGO_HOSTNAME)
IMAGE_REF ?= ${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}
INDIGO_HOME ?= /home/nonroot
GPU ?= 1
GPU_ARGS = $(if $(filter 0,$(GPU)),,--gpus all)
MLX_MODEL_REPO ?= mlx-community/gpt-oss-20b-MXFP4-Q8
MLX_MODEL_DIR ?= $(CURDIR)/.indigo/models/$(notdir $(MLX_MODEL_REPO))
MLX_MODEL ?= $(MLX_MODEL_DIR)
MLX_STATE_DIR = $(or $(INDIGO_MLX_STATE_DIR),$(CURDIR)/.indigo/mlx)
export MLX_MODEL
export INDIGO_MLX_PORT
export INDIGO_MLX_INSTANCE = $(or $(COMPOSE_PROJECT_NAME),indigo)

prepare: format lint check

format:
	@dos2unix --quiet $(FORMAT_FILES)
	@shfmt --write $(SHELL_FILES)

check:
	@shfmt --diff $(SHELL_FILES)
	@shellcheck $(SHELL_FILES)
	@./scripts/check.sh $(ENV_FILE)
	@set -e; for test in $(TEST_FILES); do bash "$$test"; done
	@$(MAKE) mlx-model-self-test

check-env:
	@./scripts/check.sh $(ENV_FILE)

lint:
	@hadolint $(DOCKER_FILES)
	@$(YAMLLINT) $(YAML_FILES)
	@$(COMPOSE) $(COMPOSE_ARGS) config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.cpu.yaml config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.isolated.yaml config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.cpu.yaml -f ./compose.isolated.yaml config --quiet
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.mlx.yaml config --quiet

compose-build:
	@$(COMPOSE) $(COMPOSE_ARGS) build

up:
	@$(COMPOSE) $(COMPOSE_ARGS) up --detach

up-cpu:
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.cpu.yaml up --detach

up-isolated:
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.isolated.yaml up --detach

mlx-setup:
	@./scripts/mlx-host.sh setup

mlx-model: mlx-model-download
	@python3 ./scripts/mlx-model-check.py "$(MLX_MODEL_DIR)"

mlx-model-download:
	@if [ ! -x "$(MLX_STATE_DIR)/venv/bin/hf" ] || [ ! -x "$(MLX_STATE_DIR)/venv/bin/mlx_lm.server" ]; then $(MAKE) mlx-setup; fi
	@"$(MLX_STATE_DIR)/venv/bin/hf" download "$(MLX_MODEL_REPO)" --local-dir "$(MLX_MODEL_DIR)"

mlx-model-check:
	@python3 ./scripts/mlx-model-check.py "$(MLX_MODEL)"

mlx-model-self-test:
	@python3 -m unittest discover -s tests -p 'test_mlx_model.py'

up-mlx:
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.mlx.yaml build
	@./scripts/mlx-host.sh start
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.mlx.yaml up --no-build --detach

mlx-status:
	@./scripts/mlx-host.sh status

down-mlx:
	@$(COMPOSE) $(COMPOSE_ARGS) -f ./compose.mlx.yaml down
	@./scripts/mlx-host.sh stop

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

instance:
	@./scripts/new.sh $(NAME) $(OFFSET) $(FORCE)

# Start the published image with nothing configured: no published ports, no
# volumes, no .env edits. Inference and the notebook services use the image
# defaults and are reachable inside the container only. Optional Indigo
# services stay off. Use run for host publishing.
start:
	@docker run \
		--detach \
		--interactive \
		--tty \
		--name "$(CONTAINER)" \
		--hostname "$(CONTAINER)" \
		$(GPU_ARGS) \
		--restart unless-stopped \
		--shm-size "$(INDIGO_SHM_SIZE)" \
		"$(IMAGE_REF)"

# Run the published image without Compose or this repository, publishing the
# ports and mounting the volumes declared in .env. Optional Indigo services are
# enabled so the published ports have listeners. --interactive and --tty are
# required: the image's default command is an interactive zsh, which exits at
# once without a TTY and turns the container into a restart loop.
run:
	@docker run \
		--detach \
		--interactive \
		--tty \
		--name "$(CONTAINER)" \
		--hostname "$(CONTAINER)" \
		$(GPU_ARGS) \
		--restart unless-stopped \
		--shm-size "$(INDIGO_SHM_SIZE)" \
		--env INDIGO_ENABLE_FILESYSTEM=1 \
		--env INDIGO_ENABLE_RUST_ANALYZER=1 \
		--env INDIGO_ENABLE_OPENVIKING=1 \
		--env INDIGO_ENABLE_PINOKIO=1 \
		--env PINOKIO_DOMAIN="$(PINOKIO_DOMAIN)" \
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

image-smoke:
	@docker run --rm --entrypoint /bin/bash "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}" \
		-lc 'test -x /healthcheck && command -v llama-swap && command -v llama-server && test -r /etc/indigo/defaults/llama-swap.yaml'

push:
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:${VERSION}"
	@docker push "${REGISTRY}/${REGISTRY_PROJECT}/${IMAGE}:latest"
