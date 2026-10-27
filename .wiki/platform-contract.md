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

Rechecked 2026-10-27. `make start GPU=0` and `make run GPU=0` omit `--gpus all`; `tests/run-platform.sh` checks both modes. `compose.cpu.yaml` only removes the GPU reservation. The default image still installs CUDA. The Apple Silicon path built from the pinned Notebook 1.0.5 ARM64 base and reached native MLX plus the router. [Platform evidence](../docs/platform-support.md) records raw model control tokens in streamed output, a textual tool call with no `tool_calls`, and an inherited x86-64 code-server Node binary that prevents full container health. No routed model-serving acceptance has passed.

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
- Prerequisites: REP-01; provisioned builder and approved CPU model fixture
- Exact write set: `Dockerfile`, `scripts/build_llama_cpp_from_source.sh`, `compose.cpu-build.yaml`, `docs/platform-support.md`
- Primary integration lock: image-build
- Outcome: Split common runtime setup from GPU and CPU targets, keep the GPU target as the default, and make `compose.cpu-build.yaml` select the CPU target together with `compose.cpu.yaml`.
- Focused validation: Build the CPU target and inspect dependencies for CUDA requirements; serve the approved small model on a CPU-only Docker host; compare artifact size.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## PLT-03 — Verify the native Apple Silicon MLX route

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: PLT-04 and PLT-05; Apple Silicon Mac with a working Docker daemon and complete approved MLX-format model
- Exact write set: `scripts/mlx-acceptance.py`, `docs/platform-support.md`
- Primary integration lock: mac-inference-validation
- Outcome: Add a repeatable host acceptance command and record a successful native MLX to container router to client path, or retain this phase with the precise failure. This recorded success is the required gate for UZU-01.
- Focused validation: Build and start `make up-mlx`; verify native `/health`, routed `/v1/models`, a streamed `/v1/chat/completions` reply, and a complete tool-call plus tool-result round trip through port 10732. Check stop and restart without replacing existing router/client config. Record macOS/SoC/RAM, image digest, `mlx-lm` version, model ID/hash, commands and results in `docs/platform-support.md`; use only test-owned state.
- Handoff: Keep the MLX result in durable platform documentation, remove PLT-03 only after every acceptance check passes, and replace UZU-01's phase-ID prerequisite with the recorded evidence when updating the network and parallel guide. The 2026-10-27 check failed; PLT-04 and PLT-05 track the separate repairs.

## PLT-04 — Restore clean streamed output and structured MLX tool calls

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: Apple Silicon Mac and an approved tool-capable MLX checkpoint; the failing GPT-OSS fixture is already available
- Exact write set: `scripts/mlx-host.sh`, `scripts/mlx-acceptance.py`, `tests/mlx-host.sh`, `docs/platform-support.md`
- Primary integration lock: mac-inference-validation
- Outcome: Determine whether the pinned `mlx-lm` server, the checkpoint template, or their combination causes raw channel markers and textual tool invocations. Select and record a compatible server/checkpoint contract without rewriting user model files or accepting malformed API output.
- Focused validation: Reproduce both failures through port 10732, then run the same streamed completion and tool-call/tool-result checks with the corrected contract. Record server version, checkpoint hashes, exact request/response shape, and any version or model change.
- Handoff: Preserve the passing or failing protocol evidence in platform documentation. Remove this phase only when the structured API contract passes; then unblock PLT-03's client and restart checks.

## PLT-05 — Correct the inherited ARM64 code-server bundle

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: Access to the Notebook image build/release system and an ARM64 Docker validation host
- Exact write set: `jhwohlgemuth/notebook` image build and release, plus INDIGO `.env`, `Dockerfile`, `docs/dependency-updates.md`, `docs/platform-support.md`
- Primary integration lock: image-build
- Outcome: Publish or select a Notebook ARM64 base whose code-server Node executable is ARM64, then update INDIGO's reviewed tag and digest pair.
- Focused validation: Inspect the executable's ELF machine ID in the new base, rebuild the INDIGO ARM64 image, and run `make runtime-smoke IMAGE_REF=ghcr.io/jhwohlgemuth/indigo:0.1.4-mlx-arm64` to verify code-server and all default services reach health.
- Handoff: Record the new base and image digests plus the passing startup result. Remove this phase only after the ARM64 runtime passes, then unblock PLT-03.

