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

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `compose.cpu.yaml` only removes the GPU reservation. The image still installs a CUDA toolkit and builds the CUDA backend. CI runs on Ubuntu and renders Compose on Windows but provides no architecture or macOS runtime evidence. README's macOS row does not distinguish Apple Silicon from Intel. `make start` and `make run` always request GPUs.

## Boundaries and decisions

First document tested support versus unverified emulation. Keep native ARM64 as a separate future decision; this plan does not promise an ARM64 port or new GPU backend. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Users can identify tested host/architecture combinations; standalone Make commands support CPU mode; a CPU build target can serve a tiny model without CUDA dependencies.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## PLT-01 — State and support the current CPU launch contract

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `Makefile`, `README.md`, `docs/platform-support.md`, `tests/run-platform.sh`
- Primary integration lock: standalone-launch
- Outcome: Add an explicit CPU option to standalone Make targets and document shell/Compose prerequisites.
- Focused validation: Inspect CPU/GPU docker argument variants; verify empty GPU option works; distinguish native versus emulated architecture in the support table.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## PLT-02 — Separate CPU inference build and runtime dependencies

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: REP-01; provisioned builder and approved CPU model fixture
- Exact write set: `Dockerfile`, `scripts/build_llama_cpp_from_source.sh`, `compose.cpu-build.yaml`, `docs/platform-support.md`
- Primary integration lock: image-build
- Outcome: Provide an opt-in CPU image target while preserving GPU behavior.
- Focused validation: Build the CPU target and inspect dependencies for CUDA requirements; serve the approved small model on a CPU-only Docker host; compare artifact size.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

