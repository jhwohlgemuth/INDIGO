---
type: Plan
title: Verify platform support and a genuine CPU path
description: Users can identify tested host/architecture combinations; standalone Make commands support CPU mode; a CPU build target can serve a tiny model without CUDA dependencies.
difficulty: high
impact: high
package: [indigo]
tags: [platform-contract, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Verify platform support and a genuine CPU path

## Current evidence

Rechecked 2026-10-22 at commit db2c536517837492b31007cf86688ec6b7e23fa3 with local changes. `make start GPU=0` and `make run GPU=0` now omit `--gpus all`; `tests/run-platform.sh` checks both modes. `docs/platform-support.md` distinguishes configuration and build evidence from runtime validation by host and architecture. `compose.cpu.yaml` only removes the GPU reservation. The image still installs a CUDA toolkit and builds the CUDA backend, so a CPU inference path remains unverified.

## Boundaries and decisions

Use `GPU=0` as the standalone Make interface for omitting `--gpus all`; keep GPU mode as the default. Document tested host/architecture combinations separately from unverified emulation. Build an opt-in CPU image target without installing CUDA, while preserving the default GPU image target. Native ARM64 and new GPU backends remain separate future decisions. No Docker daemon was available for CPU inference verification.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Users can identify tested host/architecture combinations; standalone Make commands support CPU mode; a CPU build target can serve a tiny model without CUDA dependencies.

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

