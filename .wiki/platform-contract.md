---
type: Plan
title: Verify platform support, CPU inference, and Apple Silicon MLX
description: Users can identify tested host/architecture combinations; native MLX on Apple Silicon and a CUDA-free CPU image have recorded model-serving evidence.
difficulty: high
impact: high
package: [indigo]
tags: [platform-contract, project-review]
status: in-progress
execution: phased
phase_budget_hours: 5
---

# Verify platform support, CPU inference, and Apple Silicon MLX

## Current evidence

Rechecked 2026-11-01. `make start GPU=0` and `make run GPU=0` omit `--gpus all`; `tests/run-platform.sh` checks both modes. `compose.cpu.yaml` only removes the GPU reservation. The default image still installs CUDA. On Apple Silicon, `mlx-lm==0.32.2` with the pinned Qwen3 4B checkpoint passed clean native and routed streaming, a structured tool call, and the tool-result continuation. [Platform evidence](../docs/platform-support.md) keeps the incompatible GPT-OSS result separate. INDIGO now overlays the inherited x86-64 code-server tree with the same 4.143.1 release from its pinned official multi-platform image. The rebuilt ARM64 image reports AArch64 for Node and runtime-selected native modules, and the complete container/MCP runtime smoke passes. PLT-03 now remains for OpenCode selection and restart/preservation acceptance.

## Boundaries and decisions

Use `GPU=0` as the standalone Make interface for omitting `--gpus all`; keep GPU mode as the default. Document tested host/architecture combinations separately from unverified emulation. Build an opt-in CPU image target without installing CUDA, while preserving the default GPU image target. Verify the existing native Apple Silicon MLX route before starting [optional Uzu support](uzu-support.md). Other native ARM64 and GPU backends remain separate decisions.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Users can identify tested host/architecture combinations; standalone Make commands support CPU mode; a CPU build target can serve a tiny model without CUDA dependencies; the Apple Silicon MLX path has a recorded routed streaming completion and tool-call round trip.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## PLT-02 — Separate CPU inference build and runtime dependencies

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: provisioned builder and approved CPU model fixture
- Exact write set: `Dockerfile`, `scripts/build_llama_cpp_from_source.sh`, `compose.cpu-build.yaml`, `docs/platform-support.md`
- Primary integration lock: image-build
- Outcome: Split common runtime setup from GPU and CPU targets, keep the GPU target as the default, and make `compose.cpu-build.yaml` select the CPU target together with `compose.cpu.yaml`.
- Focused validation: Build the CPU target and inspect dependencies for CUDA requirements; serve the approved small model on a CPU-only Docker host; compare artifact size.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## PLT-03 — Verify the native Apple Silicon MLX route

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: Apple Silicon Mac with a working Docker daemon and the qualified Qwen3 MLX checkpoint
- Exact write set: `scripts/mlx-acceptance.py`, `docs/platform-support.md`
- Primary integration lock: mac-inference-validation
- Outcome: Add a repeatable host acceptance command and record a successful native MLX to container router to client path, or retain this phase with the precise failure. This recorded success is the required gate for UZU-01.
- Focused validation: Build and start `make up-mlx`; verify native `/health`, routed `/v1/models`, a streamed `/v1/chat/completions` reply, and a complete tool-call plus tool-result round trip through port 10732. Check stop and restart without replacing existing router/client config. Record macOS/SoC/RAM, image digest, `mlx-lm` version, model ID/hash, commands and results in `docs/platform-support.md`; use only test-owned state.
- Handoff: Keep the MLX result in durable platform documentation, remove PLT-03 only after every acceptance check passes, and replace UZU-01's phase-ID prerequisite with the recorded evidence when updating the network and parallel guide. The qualified Qwen3 protocol and full ARM64 runtime checks pass; OpenCode selection and restart/preservation checks remain.

