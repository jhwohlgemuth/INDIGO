# Indigo — Isolated Native Development Instance for Generative Operations

> A local workshop for agentic software development: local-first, agents-first,
> and safe on the host by default.

Indigo packages local OpenAI-compatible inference and an optional complete
agent-development workstation. Choose the experience you need:

| Experience | Command | What starts |
| --- | --- | --- |
| Standalone image | `docker run … indigo:latest` | Inference plus the base notebook tools |
| Full workstation | `docker compose up --build --detach` | Inference, notebooks, OpenViking, Pinokio, Filesystem MCP, and Rust Analyzer MCP |

Published ports bind to `127.0.0.1` by default. A model is not baked into the
image; put the default model at `.indigo/models/gpt-oss-20b`, mount an existing
model directory, or select another local model with the variables below.

## Quick start: standalone image

This is the smallest useful Indigo deployment. It publishes only the
OpenAI-compatible endpoint and leaves optional Indigo services disabled.

Windows PowerShell with an NVIDIA GPU:

```powershell
docker run --detach --tty --gpus all --name indigo --restart unless-stopped --shm-size 2g --publish 127.0.0.1:10732:10732 --volume "${HOME}\.models:/home/nonroot/.models" ghcr.io/jhwohlgemuth/indigo:latest
```

Linux with an NVIDIA GPU:

```shell
docker run --detach --tty --gpus all --name indigo --restart unless-stopped --shm-size 2g --publish 127.0.0.1:10732:10732 --volume "$HOME/.models:/home/nonroot/.models" ghcr.io/jhwohlgemuth/indigo:latest
```

For CPU-only Linux or macOS, use the same command without `--gpus all`. GPU
acceleration in Docker Desktop is currently a Windows/WSL2 feature; macOS runs
this image through Docker's Linux virtual machine without NVIDIA passthrough.

The default endpoint is `http://127.0.0.1:10732/v1`. To select another model,
give it a stable API name and its path inside the container:

```shell
docker run --detach --tty --gpus all --name indigo --restart unless-stopped --shm-size 2g \
  --publish 127.0.0.1:10732:10732 \
  --env INDIGO_DEFAULT_MODEL=my-model \
  --env INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/my-model/model.gguf \
  --volume "$HOME/.models:/home/nonroot/.models" \
  ghcr.io/jhwohlgemuth/indigo:latest
```

The model name may contain letters, numbers, dots, underscores, and hyphens.
Indigo creates its initial `llama-swap` and OpenCode configuration from these
values without overwriting existing configuration.

## Quick start: full workstation

From a checkout of this repository:

```shell
docker compose up --build --detach
docker compose ps
```

That is the complete setup. Persistent, host-visible data is created under
`.indigo/`:

- `.indigo/workspace` — code visible to Indigo and its MCP servers
- `.indigo/models` — local model files
- `.indigo/llama-swap` — generated or user-maintained router configuration

To use existing host directories instead, set `INDIGO_WORKSPACE_PATH`,
`INDIGO_MODELS_PATH`, and optionally `INDIGO_LLAMA_SWAP_CONFIG_PATH` before
starting Compose. For example, in PowerShell:

```powershell
$env:INDIGO_WORKSPACE_PATH = "${HOME}\dev"
$env:INDIGO_MODELS_PATH = "${HOME}\.models"
$env:INDIGO_LLAMA_SWAP_CONFIG_PATH = "${HOME}\.config\llama-swap"
docker compose up --build --detach
```

Or in a POSIX shell:

```shell
INDIGO_WORKSPACE_PATH="$HOME/dev" \
INDIGO_MODELS_PATH="$HOME/.models" \
INDIGO_LLAMA_SWAP_CONFIG_PATH="$HOME/.config/llama-swap" \
docker compose up --build --detach
```

For a completely Docker-managed deployment with no host bind mounts:

```shell
docker compose -f compose.yaml -f compose.isolated.yaml up --build --detach
```

For a CPU-only full deployment:

```shell
docker compose -f compose.yaml -f compose.cpu.yaml up --build --detach
```

The two overrides can be combined.

## Services

| Service | Host endpoint |
| --- | --- |
| OpenAI-compatible inference | `http://127.0.0.1:10732/v1` |
| code-server | `https://127.0.0.1:1337` |
| Verdaccio | `https://127.0.0.1:4873` |
| Jupyter | `https://127.0.0.1:13337` |
| Marimo | `http://127.0.0.1:13338` |
| OpenViking | `http://127.0.0.1:1933` |
| Pinokio | `http://127.0.0.1:42000` |
| Pinokio application proxy | `http://127.0.0.1:42080` |
| Filesystem MCP | `http://127.0.0.1:11002/mcp` |
| Rust Analyzer MCP | `http://127.0.0.1:11003/mcp` |

OpenViking waits for a valid configuration on first use. Initialize it and
restart the stack:

```shell
docker compose exec indigo openviking-server init
docker compose exec indigo openviking-server doctor
docker compose restart indigo
```

The full healthcheck treats unconfigured OpenViking as waiting, not failed. It
requires every other enabled service to respond.

## Operating modes and configuration

The published image uses conservative service defaults. Compose enables the
complete workstation explicitly.

| Variable | Image default | Full Compose default |
| --- | --- | --- |
| `INDIGO_ENABLE_INFERENCE` | `1` | `1` |
| `INDIGO_ENABLE_FILESYSTEM` | `0` | `1` |
| `INDIGO_ENABLE_RUST_ANALYZER` | `0` | `1` |
| `INDIGO_ENABLE_OPENVIKING` | `0` | `1` |
| `INDIGO_ENABLE_PINOKIO` | `0` | `1` |

Accepted enabled values are `1`, `true`, `yes`, and `on`. Disabled services do
not participate in the container healthcheck.

Common network and model settings are:

```dotenv
INDIGO_PUBLISH_HOST=127.0.0.1
INDIGO_DEFAULT_MODEL=gpt-oss-20b
INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/gpt-oss-20b
INFERENCE_PUBLISHED_PORT=10732
OPENVIKING_PUBLISHED_PORT=1933
PINOKIO_PUBLISHED_PORT=42000
PINOKIO_PROXY_PUBLISHED_PORT=42080
MCP_FILESYSTEM_PUBLISHED_PORT=11002
MCP_RUST_ANALYZER_PUBLISHED_PORT=11003
```

Set `RUST_ANALYZER_WORKSPACE` to a Rust project inside the mounted workspace
when its `Cargo.toml` is below the workspace root.

## Agent configuration

The container seeds OpenCode and Codex configuration only when the destination
file does not exist. OpenCode points at Indigo inference and the enabled MCP
endpoints. Codex receives the MCP endpoints but no forced model configuration.

For clients running on the host, canonical MCP-only templates are provided at
[`config/agents/opencode.host.json`](config/agents/opencode.host.json) and
[`config/agents/codex.host.toml`](config/agents/codex.host.toml). ACORN can then
own the host's current model inventory:

```shell
acorn sync --opencode --dry-run
acorn sync --opencode
```

Indigo never overwrites host dotfiles.

## Pinokio proxy and external access

Pinokio's managed Caddy proxy exposes HTTP, HTTPS, and WebSocket applications
through port `42080`, normally as `<app>-pinokio.localhost:42080`. Raw TCP or
UDP applications still require an explicit port mapping.

Setting `INDIGO_PUBLISH_HOST=0.0.0.0` exposes every Compose-published service to
the network. Do this only behind an authenticated, TLS-terminating gateway:
the MCP services do not provide inbound authentication, and Filesystem MCP can
modify the mounted workspace.

## Routine commands

```shell
make up              # full NVIDIA stack
make up-cpu          # full CPU-only stack
make up-isolated     # full stack with Docker-managed data
make ps
make logs
make restart
make down
```

Before submitting changes:

```shell
make prepare
```

`prepare` normalizes repository text files, formats shell scripts, runs
ShellCheck and Hadolint, validates YAML, and validates every Compose mode.

## Platform support

| Host | Supported path |
| --- | --- |
| Linux + NVIDIA | Standalone or full stack with GPU |
| Windows + WSL2 + NVIDIA | Standalone or full stack with GPU |
| Linux CPU-only | Standalone or `compose.cpu.yaml` |
| macOS | CPU-only; no NVIDIA passthrough |
| AMD GPU | No accelerated path is currently packaged |

The container itself is Linux-based and depends on the versioned
`ghcr.io/jhwohlgemuth/notebook` base-image contract described in
[`ARCHITECTURE.md`](ARCHITECTURE.md).
