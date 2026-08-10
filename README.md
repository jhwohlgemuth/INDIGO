# Goldsmith

> A local workshop for agentic software development.

Goldsmith is a containerized development environment for running local models,
coding agents, and agentic software workflows. It combines the browser-based
development services inherited from [Gold Notebook](https://github.com/jhwohlgemuth/gold) with a local, OpenAI-compatible
inference endpoint managed by [llama-swap](https://github.com/mostlygeek/llama-swap).

## Quick start

Build the image:

```shell
make build
```

Create a persistent model directory and start Goldsmith with NVIDIA GPU access:

```shell
docker run --rm -it \
    --gpus all \
    --name goldsmith \
    --hostname goldsmith \
    --publish 10732:10732 \
    --publish 1337:1337 \
    --volume ~/.models:/home/nonroot/.models \
    ghcr.io/jhwohlgemuth/goldsmith:0.1.0
```

The inference router is available at `http://localhost:10732`. The inherited
[code-server](https://github.com/coder/code-server) interface is available at `https://localhost:1337`.

Goldsmith expects model directories beneath `/home/nonroot/.models`. Model
acquisition and generated llama-swap configuration belong to Acorn; this
repository owns the container runtime, service supervision, and health contract.

## Runtime contract

| Interface | Default |
| --- | --- |
| Inference API | `http://localhost:10732` |
| Health endpoint | `http://localhost:10732/health` |
| Model storage | `/home/nonroot/.models` |
| Context size | `LLAMA_ARG_CTX_SIZE=0` |
| Parallel slots | `LLAMA_ARG_N_PARALLEL=2` |

Goldsmith currently builds on the explicitly versioned
`ghcr.io/jhwohlgemuth/notebook:1.0.4` image. See [ARCHITECTURE.md](ARCHITECTURE.md)
for the dependency contract and future decoupling plan.

## Relationship to Gold

Goldsmith originated as Gold's agentic environment and is now maintained as an
independent product. Gold focuses on provably correct software; Goldsmith
focuses on equipping local AI agents to help build software — both can be used together for much win.
