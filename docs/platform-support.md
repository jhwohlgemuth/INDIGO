# Platform evidence

Indigo currently publishes one Linux image that installs a CUDA toolkit and
builds a CUDA-capable `llama-server`. Disabling a runtime GPU reservation does
not remove those image dependencies. The current CI workflow builds on an
Ubuntu runner and checks Compose rendering on Windows; it does not boot the
service or serve a model. No host/architecture combination has recorded
model-serving acceptance evidence yet.

| Host and architecture | Configured launch path | Runtime evidence |
| --- | --- | --- |
| Linux x86_64 with NVIDIA | `make run` or `docker compose up` | Image build configured in CI; no recorded model-serving result |
| Linux x86_64 without GPU | `make run GPU=0` or `compose.cpu.yaml` | GPU request removed; current image remains CUDA-based; no recorded model-serving result |
| Windows x86_64 with WSL2 and NVIDIA | Compose or standalone GPU launch | Compose rendering checked in CI; no recorded runtime result |
| Windows x86_64 with WSL2, CPU only | `compose.cpu.yaml` or `make run GPU=0` | Compose rendering checked in CI; no recorded runtime result |
| macOS Intel, Docker Linux VM | CPU launch without `--gpus all` | No recorded runtime result |
| macOS Apple Silicon, Docker Linux VM | x86_64 image emulation, CPU launch | No recorded runtime result; native ARM64 image unverified |
| Linux with AMD GPU | CPU launch only | No accelerated backend packaged |

For a standalone image, `GPU=0` omits Docker's `--gpus all` flag from both
`make start` and `make run`; the default remains `GPU=1`. For Compose, combine
`compose.yaml` with `compose.cpu.yaml` to remove its GPU reservation. A future
CPU image target needs a separate build and a small-model completion on a
CPU-only Docker host before it can be called a verified CPU inference path.
