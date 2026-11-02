# Troubleshooting

Diagnose INDIGO in this order: container, router, model, then client. Each layer
can be healthy while the next one is not.

```pikchr
scale = 0.8
Container: box "Container" wid 1.0in ht 0.5in rad 0.08in fill 0xEDE9FE thickness 0
arrow right 0.45in thick color 0x5B4BC4
Router: box "Router" wid 0.9in ht 0.5in rad 0.08in fill 0xF3F0FF thickness 0
arrow right 0.45in thick color 0x5B4BC4
Model: box "Model load" wid 1.0in ht 0.5in rad 0.08in fill 0xE0E7FF thickness 0
arrow right 0.45in thick color 0x5B4BC4
Client: box "Client" wid 0.9in ht 0.5in rad 0.08in fill 0xF3E8FF thickness 0
text "start here" color 0x5B4BC4 at Container+(0,0.55in)
text "advance only after each gate passes" color 0x5B4BC4 at Model+(0,-0.55in)
```

## Quick diagnostics

```shell
make ps
make logs
curl --fail --silent --show-error http://127.0.0.1:10732/v1/models
```

For a second instance, add its environment file to every Make command, for
example `make ps ENV_FILE=.env.two`.

## The container does not start

### Docker reports no GPU runtime

The default Compose deployment requests a GPU and the standalone command uses
`--gpus all`. Install the NVIDIA container toolkit or use:

```shell
make up-cpu
```

For the standalone targets, add `GPU=0`. These options remove the runtime GPU
request; the current image still contains CUDA dependencies and is not yet a
verified CUDA-free CPU inference image.

### A host port is already allocated

Validate the environment for missing, duplicate, or out-of-range values:

```shell
make check-env
```

This does not prove that another process is not listening. `scripts/new.sh`
checks listening TCP ports with `lsof` when available and prints warnings, but
it still writes the instance file. Review those warnings and choose another
offset:

```shell
scripts/new.sh two 1000
```

Docker is the final authority: startup fails if it cannot bind a requested
host port.

## The container is healthy but no model responds

The aggregate healthcheck proves service liveness without forcing a lazy model
load. Confirm all of the following:

1. The selected GGUF exists below `.indigo/models`.
2. `INDIGO_DEFAULT_MODEL_PATH` uses the corresponding container path below
   `/home/nonroot/.models`.
3. `/v1/models` includes the alias from `INDIGO_DEFAULT_MODEL`.
4. A `/v1/chat/completions` request succeeds.

Inspect the rendered values and router state:

```shell
docker compose config
docker compose exec -T indigo \
  cat /home/nonroot/.config/llama-swap/config.yaml
```

The bundled router launches `llama-server` with `--offline`; missing weights are
not downloaded on first request. Use ACORN's `download model` workflow or place
the compatible GGUF file in the configured host model directory.

## `/v1/models` works but chat fails

Model discovery reflects router configuration, not a successful weight load.
Check the container logs around the first request:

```shell
make logs
```

Common causes are a wrong container path, incomplete or incompatible model
files, insufficient memory, or parameters too large for the selected host.
Reduce `LLAMA_ARG_CTX_SIZE`, `LLAMA_ARG_BATCH`, `LLAMA_ARG_UBATCH`, or
`LLAMA_ARG_N_PARALLEL` one at a time and retry with the intended model.

The first request can legitimately be slow while the model loads. Use a bounded
client timeout long enough for that initial load; do not infer success from an
indefinitely hanging request.

## OpenCode selects the wrong model or MCP set

INDIGO seeds `~/.config/opencode/opencode.json` only when the file is absent.
The named configuration volume survives container recreation, and changing
`INDIGO_DEFAULT_MODEL` or switching between full and minimal mode does not
overwrite it.

Inspect the active file:

```shell
docker compose exec -T indigo \
  cat /home/nonroot/.config/opencode/opencode.json
```

Update user-owned configuration deliberately. For a clean-room test, use a
new instance name or a disposable Compose project instead of deleting a normal
user volume.

Full Compose enables Filesystem MCP, Rust Analyzer MCP, and OpenViking on first
seed. Minimal and lean direct-image modes disable those entries because the
services are off. An enabled MCP entry cannot make a disabled service exist.

## OpenViking is waiting or unreachable

OpenViking waits for a valid configuration on first use. Initialize and check
it inside the container:

```shell
docker compose exec indigo openviking-server init
docker compose exec indigo openviking-server doctor
```

Before `ov.conf` exists, the healthcheck reports OpenViking as `WAIT` without
making the whole container unhealthy. The service retries invalid configuration
on a bounded interval.

The default listener is `127.0.0.1` inside the container because unauthenticated
development mode cannot bind externally. Changing only the host publish address
or port does not make it reachable from the host. External access requires an
authenticated override and an intentionally network-facing container listener.

## Filesystem or Rust Analyzer MCP is unavailable

Confirm the full stack is in use and the services were enabled at first seed.
Their health endpoints are:

```shell
curl --fail http://127.0.0.1:11002/healthz
curl --fail http://127.0.0.1:11003/healthz
```

Rust Analyzer starts against `/home/nonroot/dev` by default. Set
`RUST_ANALYZER_WORKSPACE` to the directory containing the intended
`Cargo.toml` when the project is below that root.

## Apple Silicon MLX issues

- A GGUF file is not an MLX model; use an MLX-format directory or Hugging Face
  MLX repository.
- `http://127.0.0.1:10733/` returning 404 is expected. Check `/health`.
- Port 10733 is the native host server; clients should normally use INDIGO's
  routed endpoint on 10732.
- If the host service settings changed, run `make down-mlx` before restarting.
- Inspect `.indigo/mlx/*.log` and run `make mlx-status` for launch-agent state.

The recorded tool-capable acceptance checkpoint is
`mlx-community/Qwen3-4B-Instruct-2507-4bit`. The earlier GPT-OSS checkpoint is
retained as incompatible protocol evidence in [platform support](platform-support.md).

## Persistence and cleanup

`make down` removes the Compose container and network, not named volumes or
host bind-mounted state. Default host-visible data is under `.indigo/`;
OpenCode, Codex, OpenViking, Pinokio, and Cargo state is in named volumes.

Before removing a volume, identify its Compose project and back up any user
configuration. Use a new test-owned project when the goal is to reproduce
first-run seeding without risking normal state.
