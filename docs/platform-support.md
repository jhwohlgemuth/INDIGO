# Platform evidence

Indigo currently publishes one Linux image that installs a CUDA toolkit and builds a CUDA-capable `llama-server`.
Disabling a runtime GPU reservation does not remove those image dependencies.
The current CI workflow builds on an Ubuntu runner and checks Compose rendering on Windows; it does not boot the service or serve a model.
No host/architecture combination has recorded model-serving acceptance evidence yet.

## Evidence matrix

The table below separates the launch path each platform is *configured* to use from the runtime evidence actually *recorded* for it.

| Host and architecture | Configured launch path | Runtime evidence |
| --- | --- | --- |
| Linux x86_64 with NVIDIA | `make run` or `docker compose up` | Image build configured in CI; no recorded model-serving result |
| Linux x86_64 without GPU | `make run GPU=0` or `compose.cpu.yaml` | GPU request removed; current image remains CUDA-based; no recorded model-serving result |
| Windows x86_64 with WSL2 and NVIDIA | Compose or standalone GPU launch | Compose rendering checked in CI; no recorded runtime result |
| Windows x86_64 with WSL2, CPU only | `compose.cpu.yaml` or `make run GPU=0` | Compose rendering checked in CI; no recorded runtime result |
| macOS Intel, Docker Linux VM | CPU launch without `--gpus all` | No recorded runtime result |
| macOS Apple Silicon, Docker Linux VM | `make up-mlx MLX_MODEL=...`, ARM64 CPU INDIGO image and native host MLX | Build and model-serving runtime validation pending |
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
