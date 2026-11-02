# Isolated Native Development Instance for Generative Operations (INDIGO)

> A local workshop for agentic software development — local-first, agent native

INDIGO combines a local OpenAI-compatible model router, OpenCode, notebook
services, and optional workspace/context services in one persistent development
environment. Linux inference uses `llama-swap` with `llama.cpp`; Apple Silicon
can opt into a native MLX peer.

## Start here

New users should follow the [verified first-response guide](docs/getting-started.md).
It covers model acquisition, configuration, service readiness, one real chat
completion, and the first OpenCode request.

- [Getting started](docs/getting-started.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Platform evidence](docs/platform-support.md)
- [Architecture and trust boundaries](ARCHITECTURE.md)

INDIGO does not download a GGUF model automatically. [ACORN](https://acorn.ornl.gov/cli-reference/model-workflows.html)
owns model discovery and acquisition; INDIGO mounts the selected files and
serves the configured path.

## What “ready” means

These checks prove different things. Do not stop at the first green result.

```pikchr
scale = 0.8
Start: circle radius 0.07in fill 0x5B4BC4 thickness 0
arrow right 0.42in thick color 0x5B4BC4
Container: box "Container" "started" wid 1.0in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0
arrow right 0.42in thick color 0x5B4BC4
Router: box "Router" "live" wid 0.9in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0
arrow right 0.42in thick color 0x5B4BC4
Model: box "Model" "usable" wid 0.9in ht 0.52in rad 0.08in fill 0xE0E7FF thickness 0
arrow right 0.42in thick color 0x5B4BC4
Client: box "Client" "verified" wid 0.9in ht 0.52in rad 0.08in fill 0xF3E8FF thickness 0
arrow right 0.42in thick color 0x5B4BC4
End: circle radius 0.1in fill white thickness 0
circle radius 0.05in fill 0x5B4BC4 thickness 0 at End
```

| Gate | Check | What it proves |
| --- | --- | --- |
| Container started | `make ps` | The container and supervised services started |
| Router live | `curl http://127.0.0.1:10732/v1/models` | The router is reachable and advertises configured model aliases |
| Model usable | Send a request to `/v1/chat/completions` | The selected weights load and generate a response |

The first model request may take longer because `llama-swap` loads the model on
demand. A healthy container or populated `/v1/models` response is not
model-serving evidence by itself.

## Services

| Service | Purpose | Default host access[^ports] |
| --- | --- | --- |
| [llama-swap](https://github.com/mostlygeek/llama-swap) | Local OpenAI-compatible models | `http://127.0.0.1:10732/v1` |
| code-server | Browser IDE | `https://127.0.0.1:1337` |
| [OpenViking](https://github.com/volcengine/OpenViking) | Context database, Studio, and MCP | Container-local by default |
| [Pinokio](https://github.com/pinokiocomputer/pinokio) | Application manager | `http://127.0.0.1:42000` |
| Pinokio proxy | Stable ingress for dynamic web apps | `http://127.0.0.1:42080` |
| Filesystem MCP | Workspace-scoped file operations | `http://127.0.0.1:11002/mcp` |
| Rust Analyzer MCP | Rust diagnostics and navigation | `http://127.0.0.1:11003/mcp` |

## Deployment choices

| Mode | Command | Notes |
| --- | --- | --- |
| Full Compose | `make up` | Starts the full stack with host-visible workspace, model, and router paths |
| CPU launch | `make up-cpu` | Removes the GPU reservation; the current image still contains CUDA dependencies |
| Docker-managed storage | `make up-isolated` | Replaces the workspace, model, and router bind mounts with named volumes |
| Minimal | `docker compose -f compose.yaml -f compose.minimal.yaml up -d` | Disables Pinokio, OpenViking, Filesystem MCP, and Rust Analyzer MCP |
| Apple Silicon MLX | `make up-mlx` | Runs `mlx-lm` on macOS and the ARM64 INDIGO router in Docker Desktop |

The published image can also run without this repository:

```shell
docker run -dit --name indigo --hostname indigo --gpus all \
  --restart unless-stopped --shm-size 2gb \
  -p 127.0.0.1:10732:10732 \
  -p 127.0.0.1:1337:1337 \
  --volume indigo-models:/home/nonroot/.models \
  --volume indigo-opencode-config:/home/nonroot/.config/opencode \
  --volume indigo-opencode-data:/home/nonroot/.local/share/opencode \
  ghcr.io/jhwohlgemuth/indigo:0.1.4
```

This lean direct-image mode leaves Pinokio, OpenViking, Filesystem MCP, and Rust
Analyzer MCP off. On a CPU-only host, omit `--gpus all`; this changes only the
runtime GPU request.

## Configuration and persistent state

`.env` is the source of truth for the image version, instance identity, host
ports, and publish address. Validate it after editing:

```shell
make check-env
```

Compose bind-mounts these host-visible paths by default:

- `.indigo/workspace` — code shared with INDIGO and its MCP servers
- `.indigo/models` — local model files
- `.indigo/llama-swap` — generated or user-maintained router configuration

OpenCode, Codex, OpenViking, Pinokio, and Cargo state use named volumes.
First-run router and agent configuration is seeded only when its destination is
absent. Existing user configuration is not replaced on restart.

### Optional MCP defaults

Full Compose enables Filesystem MCP, Rust Analyzer MCP, and OpenViking in the
first-run OpenCode configuration. Minimal and lean direct-image modes disable
their entries because those services are off. The generated OpenCode file is
user-owned after first start, so switching modes does not rewrite its MCP flags;
update the persisted file manually or start with a fresh test-owned volume.

OpenViking remains container-local in its default unauthenticated development
mode. Publishing its host port does not make it reachable; external access
requires a separate authenticated configuration.

## Multiple instances

Create an instance-specific environment with offset ports and separate state:

```shell
scripts/new.sh foo
make up ENV_FILE=.env.foo
```

The generator rejects malformed input, duplicate generated ports, and
out-of-range ports. If `lsof` is available, an already-listening host port
produces a warning but does not prevent the file from being written. Review the
warning or choose another offset before startup; Docker reports any remaining
bind collision when the instance starts.

```shell
scripts/new.sh three 1000
make down ENV_FILE=.env.three
```

## Routine commands

```shell
make ps
make logs
make restart
make down
```

Use `make run` for the published-image path driven by `.env`, or `make start`
for an image-only container with no published ports or mounted state. Add
`GPU=0` to either standalone target to omit the runtime GPU request.

## Host OpenCode configuration

INDIGO-local OpenCode is configured inside the container. Host setup remains
external: ACORN can synchronize downloaded models into a host OpenCode client,
while `config/agents/opencode.host.json` and
`config/agents/codex.host.toml` provide canonical INDIGO MCP templates for
shell-setup tooling. ACORN preserves unrelated client settings and does not
currently synchronize Codex.

## Security

Published ports bind to `127.0.0.1` by default. Setting
`INDIGO_PUBLISH_HOST=0.0.0.0` exposes services whose container listener accepts
remote traffic. Most MCP services do not provide inbound authentication, and
Filesystem MCP can modify the shared workspace. Use remote publishing only on a
trusted network or behind an authenticated, TLS-terminating gateway.

## Development

Before submitting changes:

```shell
make prepare
```

`make check` validates shell contracts and environment files. `make lint`
validates Dockerfiles, YAML, and supported Compose combinations.

Build and preview the documentation book locally with mdBook 0.5.2 and
mdbook-pikchr 0.2.0:

```shell
cargo install --locked mdbook@0.5.2 mdbook-pikchr@0.2.0
```

```shell
make book
make book-write
```

GitLab CI validates the book in merge requests and publishes the default
branch through GitLab Pages. After the first successful deployment, find the
site URL under **Deploy > Pages** in the GitLab project.

[^ports]: Every published host port and the publish address can be changed in
    `.env`. OpenViking also binds to loopback inside the container and therefore
    remains container-local in the default configuration.
