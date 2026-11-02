# Getting started: first verified response

This guide takes a new checkout from no model to one verified response. It uses
the full Compose deployment because its model and router paths are visible under
`.indigo/` on the host.

```pikchr
scale = 0.72
Start: circle radius 0.07in fill 0x5B4BC4 thickness 0
arrow right 0.3in thick color 0x5B4BC4
Acquire: box "Acquire" "GGUF" wid 0.82in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0
arrow right 0.3in thick color 0x5B4BC4
Configure: box "Configure" ".env" wid 0.92in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0
arrow right 0.3in thick color 0x5B4BC4
StartIndigo: box "Start" "INDIGO" wid 0.92in ht 0.52in rad 0.08in fill 0xE0E7FF thickness 0
arrow right 0.3in thick color 0x5B4BC4
Gates: box "Check three" "readiness gates" wid 1.15in ht 0.52in rad 0.08in fill 0xF3E8FF thickness 0
arrow right 0.3in thick color 0x5B4BC4
OpenCode: box "Verify" "OpenCode" wid 0.92in ht 0.52in rad 0.08in fill 0xF5F3FF thickness 0
arrow right 0.3in thick color 0x5B4BC4
End: circle radius 0.1in fill white thickness 0
circle radius 0.05in fill 0x5B4BC4 thickness 0 at End
```

## 1. Prerequisites

Install:

- Docker with Compose v2;
- the NVIDIA container toolkit for the default GPU path, or plan to use
  `make up-cpu` without GPU acceleration;
- [ACORN](https://acorn.ornl.gov/getting-started.html) for GGUF model discovery
  and download.

Clone the repository and enter it:

```shell
git clone https://github.com/jhwohlgemuth/indigo.git
cd indigo
```

The current CPU override removes Docker's GPU reservation but does not remove
CUDA from the image. See [platform support](platform-support.md) before choosing
a production host.

## 2. Acquire one GGUF model

INDIGO deliberately does not download a GGUF model during startup. ACORN owns
model acquisition; INDIGO serves the file you select.

For a small onboarding fixture, download a Qwen GGUF into the directory mounted
by Compose:

```shell
acorn download model Qwen/Qwen2.5-0.5B-Instruct-GGUF \
  --quantization Q4_K_M \
  --local-dir "$PWD/.indigo/models"
find .indigo/models -type f -name '*.gguf'
```

ACORN prints the selected file and its destination. Record the path relative to
`.indigo/models`; the exact filename can vary with the selected repository and
quantization. A manually acquired compatible GGUF file can be used instead.

Importing model metadata with `acorn import model` does not download weights.
Use `acorn download model` when the GGUF file is not already present.

## 3. Point INDIGO at the file

Choose a simple router alias and set the model path inside the container. Edit
the optional overrides at the bottom of `.env`:

```dotenv
INDIGO_DEFAULT_MODEL=qwen2.5-0.5b-instruct
INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/<relative-path-from-step-2>.gguf
```

For example, if `find` reports
`.indigo/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf`, use:

```dotenv
INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
```

The alias accepts letters, numbers, dots, underscores, and hyphens. The path
must be below `/home/nonroot/.models`, which maps to `.indigo/models` in the
default Compose deployment.

Validate the environment and rendered Compose configuration before startup:

```shell
make check-env
docker compose config --quiet
```

## 4. Start INDIGO

With NVIDIA container support:

```shell
make up
```

Without NVIDIA container support:

```shell
make up-cpu
```

Follow initialization when needed:

```shell
make logs
```

Use `Ctrl-C` to stop following logs; it does not stop the stack.

## 5. Check the three readiness gates

### Container started

```shell
make ps
```

Running or healthy status proves that the container and required supervised
services started. It does not load the selected model.

### Router live

```shell
curl --fail --silent --show-error \
  http://127.0.0.1:10732/v1/models
```

Confirm that the response includes `qwen2.5-0.5b-instruct`. This proves that the
router is reachable and advertises the alias; it still does not prove that the
weights load.

### Model usable

Trigger the lazy model load and request a real response:

```shell
curl --fail --silent --show-error --max-time 600 \
  http://127.0.0.1:10732/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-0.5b-instruct",
    "messages": [{"role": "user", "content": "Reply with exactly INDIGO_READY"}],
    "stream": false,
    "temperature": 0
  }'
```

The JSON response must contain an assistant message. The first request can take
longer while `llama.cpp` loads the model; subsequent requests should avoid that
startup cost until the configured idle timeout unloads it.

## 6. Verify OpenCode

Full Compose enables its optional services and seeds OpenCode with the selected
router alias on first start. Exercise that default without a model override:

```shell
docker compose exec -T indigo \
  opencode run --format json "Reply with exactly OPENCODE_INDIGO_READY"
```

Look for `OPENCODE_INDIGO_READY` in a text event. OpenCode configuration is
persistent and user-owned after seeding; restart does not replace it.

The first-run MCP entries follow the services selected at that time:

- full Compose enables Filesystem MCP, Rust Analyzer MCP, and OpenViking;
- `compose.minimal.yaml` and the lean direct-image command disable them;
- changing modes later does not rewrite an existing OpenCode file.

OpenViking can remain in a waiting state until it has a valid `ov.conf`. That
state does not block the model response above.

## 7. Stop the stack

```shell
make down
```

This removes the Compose container and network but preserves named volumes and
the host-visible `.indigo/` directories. See [troubleshooting](troubleshooting.md)
before deleting state or changing an existing first-run configuration.

## Other supported entry points

### Minimal Compose

Use the same model steps, then start only inference and Notebook base services:

```shell
docker compose -f compose.yaml -f compose.minimal.yaml up --detach
```

The minimal preset uses one inference slot, an 8,192-token context, a 512-token
logical batch, and a 256-token physical batch. Its first-run OpenCode MCP
entries are disabled.

### Apple Silicon with MLX

MLX requires Apple Silicon, macOS 14 or newer, Docker Desktop, and native Python
3.11 or newer. A GGUF file is not an MLX model. Use the qualified tool-capable
checkpoint for the recorded acceptance path:

```shell
export MLX_MODEL_REPO=mlx-community/Qwen3-4B-Instruct-2507-4bit
export MLX_MODEL_DIR="$PWD/.indigo/models/Qwen3-4B-Instruct-2507-4bit"
export MLX_MODEL="$MLX_MODEL_DIR"
make mlx-model
make up-mlx
python3 scripts/mlx-acceptance.py
```

The native server listens on port 10733 and the routed INDIGO API remains on
10732. Stop both layers with `make down-mlx`. The native server binds to all Mac
interfaces so Docker Desktop can reach it; use a trusted network or host
firewall.

### Multiple instances

```shell
scripts/new.sh two
make up ENV_FILE=.env.two
```

The generated file has separate ports and state. Busy host ports produce
warnings when `lsof` is available; generation continues so you can review the
file or choose a different offset before startup.
