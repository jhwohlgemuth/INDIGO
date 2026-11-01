# Platform evidence

Indigo currently publishes one Linux image that installs a CUDA toolkit and builds a CUDA-capable `llama-server`.
Disabling a runtime GPU reservation does not remove those image dependencies.
The CI workflow builds a CPU validation image on an Ubuntu runner, checks Compose rendering on Windows, and includes a disposable startup smoke check. This checks startup without requiring a CUDA toolkit or GPU on the hosted runner; it does not validate the default CUDA image or serve a model.
The Apple Silicon run below reached native MLX and the container router but failed model-serving acceptance.

## Evidence matrix

The table below separates the launch path each platform is *configured* to use from the runtime evidence actually *recorded* for it.

| Host and architecture | Configured launch path | Runtime evidence |
| --- | --- | --- |
| Linux x86_64 with NVIDIA | `make run` or `docker compose up` | Image build configured in CI; no recorded model-serving result |
| Linux x86_64 without GPU | `make run GPU=0` or `compose.cpu.yaml` | GPU request removed; current image remains CUDA-based; no recorded model-serving result |
| Windows x86_64 with WSL2 and NVIDIA | Compose or standalone GPU launch | Compose rendering checked in CI; no recorded runtime result |
| Windows x86_64 with WSL2, CPU only | `compose.cpu.yaml` or `make run GPU=0` | Compose rendering checked in CI; no recorded runtime result |
| macOS Intel, Docker Linux VM | CPU launch without `--gpus all` | No recorded runtime result |
| macOS Apple Silicon, Docker Linux VM | `make up-mlx MLX_MODEL=...`, ARM64 CPU INDIGO image and native host MLX | Pinned ARM64 image built; clean routed streaming and a structured tool-result round trip passed with the qualified Qwen3 checkpoint on 2026-10-31; full container health still fails on the inherited code-server bundle |
| Linux with AMD GPU | CPU launch only | No accelerated backend packaged |

## CPU-only launch

For a standalone image, `GPU=0` omits Docker's `--gpus all` flag from both `make start` and `make run`; the default remains `GPU=1`.
For Compose, combine `compose.yaml` with `compose.cpu.yaml` to remove its GPU reservation.
Both paths only drop the runtime GPU request — the published image still bundles the CUDA toolkit.
A verified CPU inference path therefore remains future work: it needs a separate CUDA-free build plus a small-model completion on a CPU-only Docker host.

## Apple Silicon (MLX)

The MLX path uses a separate ARM64 Notebook base image, a CUDA-free INDIGO build, and a native macOS `mlx-lm` process.
`llama-swap` routes `mlx/default_model` through `host.docker.internal` while keeping the published INDIGO endpoint on host loopback.
Router liveness does not prove model serving: the Mac acceptance run must include a streamed response and a tool call through port 10732.

### Acceptance run, 2026-10-27

- Host: MacBook Pro Mac16,5, Apple M4 Max, 48 GB RAM, macOS 26.7.1; Docker Engine 29.9.1, Linux arm64.
- Image: `ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64`, local image ID `sha256:4b5de771b1149aa5ac271958b04e8716c88745443fb5863200537f1e051dea34`, built from Notebook 1.0.5 multi-platform index `sha256:c3256bd1d46ffd71f6c7b95cc0da7cca1c2ddc417070f3a7622bd557838be7dd`.
- Native server: `mlx-lm==0.32.2`; checkpoint `mlx-community/gpt-oss-20b-MXFP4-Q8`, converted by its publisher with mlx-lm 0.27.0. SHA-256 of weight shards `model-00001`/`00002`/`00003`: `57f4846924652b1b23537c6c6d6b65f64fde811e47369d4e23c5c45b4d7584a7`, `4a862a873080e489db16125877e19553b958562ff4dd0246135bc061c3293652`, `16c32bb8dbd1fa8d556815706589d6d6480d29946196cd2fe2b721d4daf84132`.
- `make mlx-model-check`, `docker compose -f compose.yaml -f compose.mlx.yaml config --quiet`, and `make image-smoke VERSION=0.1.4-mlx-arm64` passed. `make up-mlx` started native MLX and the container router. After rebuilding against the pinned base and recreating the container, `python3 scripts/mlx-acceptance.py` passed native `/health`, native `/v1/models`, and routed `/v1/models` (`mlx/default_model`).
- The routed streamed completion included raw `<|channel|>analysis` and `<|message|>` control tokens. A request for `get_temperature` produced a textual `to=functions.get_temperature` sequence in `message.content`, with no structured `tool_calls`. The tool-result round trip and OpenCode client selection therefore remain unverified. The local `mlx-lm` tokenizer parser inference has no parser match for this checkpoint's template; whether a different supported checkpoint or host-server fix resolves both output defects requires a new acceptance run.
- `make runtime-smoke IMAGE_REF=ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64` timed out: Verdaccio, Jupyter, Marimo, and the inference router passed, but code-server was unreachable. The inherited `/app/code-server/lib/node` in the pinned ARM64 image has ELF machine ID 62 (x86-64); its service log repeats `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2`. The image needs an ARM64 code-server bundle before full health can pass.

### MLX protocol diagnosis, 2026-10-31

- The installed and latest released server is still `mlx-lm==0.32.2`. The downloaded GPT-OSS checkpoint has a complete Harmony chat template but does not declare an `mlx-lm` `tool_parser_type`; the released server's parser inference has no GPT-OSS/Harmony match. Its recorded runtime warning, `Received tools but model does not support tool calling`, is therefore a server/checkpoint protocol mismatch rather than a router defect.
- Upstream [issue 875](https://github.com/ml-explore/mlx-lm/issues/875) remains open and records the same GPT-OSS channel leakage, missing or unreliable structured calls, and especially poor tool reliability for 20B variants. The upstream [0.32.2 release](https://github.com/ml-explore/mlx-lm/releases/tag/v0.32.2) contains no GPT-OSS protocol adapter. Do not add output filtering or accept recovered textual calls as structured API compatibility.
- The qualified contract is `mlx-lm==0.32.2` with `mlx-community/Qwen3-4B-Instruct-2507-4bit` at Hugging Face revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`. Its tokenizer explicitly selects the supported `json_tools` parser. Keep the GPT-OSS hashes above as failing evidence; do not rewrite its tokenizer files or use it for the routed acceptance gate.

### Compatible protocol run, 2026-10-31

- Host and image: the same MacBook Pro M4 Max and `ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64` described above. Native MLX ran in a test-owned launch agent on port 10735; an isolated `indigo-plt04` Compose project routed `mlx/default_model` through port 10732.
- Checkpoint: `mlx-community/Qwen3-4B-Instruct-2507-4bit`, revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`; `model.safetensors` SHA-256 `2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f`; tokenizer config SHA-256 `4397cc477eb6d79715ccd2000accd6b3531928f30029665832fa1b255f24d2b9`.
- `python3 scripts/mlx-model-check.py` reported one complete 2,263,022,417-byte weight shard. Running `scripts/mlx-acceptance.py` directly against the native server and again through `llama-swap` produced a clean streamed `INDIGO_READY`, a structured `get_temperature({"city":"Boston"})` call with an ID, and a final response using the supplied `17` degree result. No channel markers or textual pseudo-calls appeared.
- This closes the MLX server/checkpoint output-contract defect. PLT-03 still requires the ARM64 code-server repair, OpenCode selection, stop/restart, and preservation checks before the overall Apple Silicon path is accepted.

The MLX acceptance gate for optional Uzu work remains closed. After correcting the ARM64 image defect, rerun the qualified Qwen3 contract through `make up-mlx`, then verify OpenCode selection, stop, restart, and preserved user configuration.
