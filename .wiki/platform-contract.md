---
type: Plan
title: Verify platform support, CPU inference, and Apple Silicon MLX
description: Users can identify tested host/architecture combinations; native MLX on Apple Silicon and a CUDA-free CPU image have recorded model-serving evidence.
difficulty: high
impact: high
package: [indigo]
tags: [platform-contract, project-review]
status: waiting-on-validation
execution: phased
phase_budget_hours: 5
---

# Verify platform support, CPU inference, and Apple Silicon MLX

## Current evidence

Rechecked 2026-11-01. `make start GPU=0` and `make run GPU=0` omit `--gpus all`; `tests/run-platform.sh` checks both modes. `compose.cpu.yaml` only removes the GPU reservation. The default image still installs CUDA. On Apple Silicon, `mlx-lm==0.32.2` with the pinned Qwen3 4B checkpoint passed clean native and routed streaming, a structured tool-result round trip, default OpenCode selection, and a full stop/restart with unchanged router and client configuration. [Platform evidence](../docs/platform-support.md) keeps the incompatible GPT-OSS result separate and records the accepted path. INDIGO overlays the inherited x86-64 code-server tree with the same 4.143.1 release from its pinned official multi-platform image; the rebuilt ARM64 image reports AArch64 for Node and runtime-selected native modules, and the complete container/MCP runtime smoke passes. Only the separately blocked CUDA-free CPU image evidence remains.

## Boundaries and decisions

Use `GPU=0` as the standalone Make interface for omitting `--gpus all`; keep GPU mode as the default. Document tested host/architecture combinations separately from unverified emulation. Build an opt-in CPU image target without installing CUDA, while preserving the default GPU image target. Use the recorded native Apple Silicon MLX acceptance as the baseline for [optional Uzu support](uzu-support.md). Other native ARM64 and GPU backends remain separate decisions.

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
