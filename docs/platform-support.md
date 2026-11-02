# Platform evidence

Indigo currently publishes one Linux image that installs a CUDA toolkit and builds a CUDA-capable `llama-server`.
Disabling a runtime GPU reservation does not remove those image dependencies.
The CI workflow builds a CPU validation image on an Ubuntu runner, checks Compose rendering on Windows, and includes a disposable startup smoke check. This checks startup without requiring a CUDA toolkit or GPU on the hosted runner; it does not validate the default CUDA image or serve a model.
The Apple Silicon runs below verify the complete native MLX, container-router,
and OpenCode path. A later image repair also restored full ARM64 container
health, and a full stop/restart preserved both router and client configuration.

```pikchr
scale = 0.72
LinuxClient: box "Linux / Windows" "client" wid 1.15in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0
LinuxRouter: box "INDIGO router" ":10732" wid 1.1in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0 at LinuxClient+(1.75in,0)
Llama: box "Container" "llama.cpp" wid 1.05in ht 0.52in rad 0.08in fill 0xE0E7FF thickness 0 at LinuxRouter+(1.75in,0)
arrow from LinuxClient.e to LinuxRouter.w thick color 0x5B4BC4
arrow from LinuxRouter.e to Llama.w thick color 0x5B4BC4
MacClient: box "macOS" "client" wid 1.15in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0 at LinuxClient+(0,-0.9in)
MacRouter: box "INDIGO router" ":10732" wid 1.1in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0 at LinuxRouter+(0,-0.9in)
MLX: box "Native MLX" ":10733" wid 1.05in ht 0.52in rad 0.08in fill 0xF3E8FF thickness 0 at Llama+(0,-0.9in)
arrow from MacClient.e to MacRouter.w thick color 0x5B4BC4
arrow from MacRouter.e to MLX.w thick color 0x5B4BC4
```

## Evidence matrix

The table below separates the launch path each platform is *configured* to use from the runtime evidence actually *recorded* for it.

| Host and architecture | Configured launch path | Runtime evidence |
| --- | --- | --- |
| Linux x86_64 with NVIDIA | `make run` or `docker compose up` | Image build configured in CI; no recorded model-serving result |
| Linux x86_64 without GPU | `make run GPU=0` or `compose.cpu.yaml` | GPU request removed; current image remains CUDA-based; no recorded model-serving result |
| Windows x86_64 with WSL2 and NVIDIA | Compose or standalone GPU launch | Compose rendering checked in CI; no recorded runtime result |
| Windows x86_64 with WSL2, CPU only | `compose.cpu.yaml` or `make run GPU=0` | Compose rendering checked in CI; no recorded runtime result |
| macOS Intel, Docker Linux VM | CPU launch without `--gpus all` | No recorded runtime result |
| macOS Apple Silicon, Docker Linux VM | `make up-mlx MLX_MODEL=...`, ARM64 CPU INDIGO image and native host MLX | Clean routed streaming, a structured tool-result round trip, default OpenCode selection, and full stop/restart preservation passed with the qualified Qwen3 checkpoint; the pinned code-server overlay and full container runtime smoke also passed on ARM64 |
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
- `make runtime-smoke IMAGE_REF=ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64` timed out: Verdaccio, Jupyter, Marimo, and the inference router passed, but code-server was unreachable. The inherited `/app/code-server/lib/node` in the pinned ARM64 image has ELF machine ID 62 (x86-64); its service log repeats `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2`. This is the failure repaired by the later pinned overlay recorded below.

### MLX protocol diagnosis, 2026-10-31

- The installed and latest released server is still `mlx-lm==0.32.2`. The downloaded GPT-OSS checkpoint has a complete Harmony chat template but does not declare an `mlx-lm` `tool_parser_type`; the released server's parser inference has no GPT-OSS/Harmony match. Its recorded runtime warning, `Received tools but model does not support tool calling`, is therefore a server/checkpoint protocol mismatch rather than a router defect.
- Upstream [issue 875](https://github.com/ml-explore/mlx-lm/issues/875) remains open and records the same GPT-OSS channel leakage, missing or unreliable structured calls, and especially poor tool reliability for 20B variants. The upstream [0.32.2 release](https://github.com/ml-explore/mlx-lm/releases/tag/v0.32.2) contains no GPT-OSS protocol adapter. Do not add output filtering or accept recovered textual calls as structured API compatibility.
- The qualified contract is `mlx-lm==0.32.2` with `mlx-community/Qwen3-4B-Instruct-2507-4bit` at Hugging Face revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`. Its tokenizer explicitly selects the supported `json_tools` parser. Keep the GPT-OSS hashes above as failing evidence; do not rewrite its tokenizer files or use it for the routed acceptance gate.

### Compatible protocol run, 2026-10-31

- Host and image: the same MacBook Pro M4 Max and `ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64` described above. Native MLX ran in a test-owned launch agent on port 10735; an isolated `indigo-plt04` Compose project routed `mlx/default_model` through port 10732.
- Checkpoint: `mlx-community/Qwen3-4B-Instruct-2507-4bit`, revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`; `model.safetensors` SHA-256 `2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f`; tokenizer config SHA-256 `4397cc477eb6d79715ccd2000accd6b3531928f30029665832fa1b255f24d2b9`.
- `python3 scripts/mlx-model-check.py` reported one complete 2,263,022,417-byte weight shard. Running `scripts/mlx-acceptance.py` directly against the native server and again through `llama-swap` produced a clean streamed `INDIGO_READY`, a structured `get_temperature({"city":"Boston"})` call with an ID, and a final response using the supplied `17` degree result. No channel markers or textual pseudo-calls appeared.
- This closed the MLX server/checkpoint output-contract defect. The later ARM64 code-server repair and complete client/restart run below supplied the remaining acceptance evidence.

### ARM64 code-server repair, 2026-11-01

- Host: Docker host `Dante`, Ubuntu 24.04.5 LTS, Linux ARM64, Docker Engine 29.1.3.
- Image: local `indigo:code-server-arm64`, ID `sha256:b4fc9d782b9d2e0d5b3223a4533a044c56c64e32e626d8ab0f73ef9b3b9260cc`, 10,819,992,942 bytes. The build reused the inference and dependency layers and completed in 10 seconds.
- Repair input: official code-server 4.143.1 multi-platform image index `sha256:377b66bec5645510ed52549bb00e648c273edc604d230a3f90fd2b2433afcb97`. INDIGO copies the complete matching bundle over the inherited `/app/code-server` tree so Node and native modules move together.
- `/app/code-server/lib/node`, Argon2, node-pty, spdlog, Parcel watcher, and SQLite native modules all reported ELF machine `AArch64`; `code-server --version` reported 4.143.1 / Code 1.143.1.
- `scripts/runtime-smoke.sh indigo:code-server-arm64` passed code-server, Verdaccio, Jupyter, Marimo, inference-router, Filesystem MCP, Rust Analyzer MCP, both MCP protocol probes, and graceful shutdown. The disposable container was removed.

### Complete client and restart run, 2026-11-01

- Host: MacBook Pro Mac16,5, Apple M4 Max with 16 cores and 48 GB RAM, macOS 26.7.1. Docker Desktop used a Linux ARM64 engine. The final locally built image was `ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64`, image ID `sha256:c5f0ac6229bd916dfdeaa4c4c49253e7a2129196cac871caf424401b8a97bf15`, built from the current repository and the pinned Notebook and code-server inputs above.
- Native server and model: `mlx-lm==0.32.2`; `mlx-community/Qwen3-4B-Instruct-2507-4bit` revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`; `model.safetensors` SHA-256 `2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f`. The local `config.json` and `tokenizer.json` hashes were `574349e5a343236546fda55e4744a76e181f534182d7dc60ff1bad7e7a502849` and `aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4`.
- Isolation: the run used Compose project `indigo-plt03`, native port 10733, project-owned named volumes, and router state under `.indigo/plt03/llama-swap`. Starting with `make up-mlx` made native `/health` ready and exposed the router on 10732. `python3 scripts/mlx-acceptance.py` passed routed model discovery, streamed `INDIGO_READY`, the structured `get_temperature({"city":"Boston"})` call, and the final response using the supplied `17` degree result.
- OpenCode 2.1.3 loaded the persisted default `indigo/mlx/default_model`. Running `opencode run --format json` without `--model` returned `OPENCODE_MLX_READY`, proving client selection through the configured default rather than a command-line override.
- Before shutdown, SHA-256 was `649748bb29bc0566e33d360fef1edb2268be137dac8d9f7ad3bb62d96f2965d6` for `/home/nonroot/.config/opencode/opencode.json` and `0d6269cc535bedfeb3afff7cd7047ed73c18cf73702cf7a7bc5fac15274ea260` for `/home/nonroot/.config/llama-swap/config.yaml`. `make down-mlx` removed the container/network and stopped `org.indigo.mlx.indigo-plt03`; `make up-mlx` rebuilt and recreated the stack. Both hashes were identical after restart.
- After restart, `python3 scripts/mlx-acceptance.py` passed the complete routed protocol suite again, and default-model `opencode run --format json` returned `OPENCODE_MLX_RESTART_READY`. This closes the Apple Silicon MLX acceptance gate. It establishes the baseline required for optional Uzu evaluation; it does not itself validate Uzu.
