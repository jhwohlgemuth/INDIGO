---
type: Plan
title: Reduce measured build and idle resource costs
description: Repeatable baseline and after measurements show build/cache benefits; a service-only edit avoids recompiling inference; an opt-in minimal Compose preset reduces observed idle work without breaking documented clients.
difficulty: high
impact: medium
package: [indigo]
tags: [build-and-runtime-efficiency, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Reduce measured build and idle resource costs

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. Dockerfile copies frequently changed service/config files before expensive inference compilation. llama.cpp uses an unbounded nproc parallel build and full git clone. CI has no explicit persistent build cache or cancellation policy. Full Compose enables every optional service. The router already uses a 600-second idle-sleep option, so idle behavior must be measured rather than assumed absent.

## Boundaries and decisions

Optimize measured cold/warm build time, image bytes and idle resources without removing required developer tooling. Do not claim energy savings from wall time alone. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Repeatable baseline and after measurements show build/cache benefits; a service-only edit avoids recompiling inference; an opt-in minimal Compose preset reduces observed idle work without breaking documented clients.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## EFF-01 — Capture reproducible resource baselines

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: Accessible benchmark Docker host and fixed image input revisions
- Exact write set: `scripts/benchmark.sh`, `docs/performance.md`
- Primary integration lock: performance-evidence
- Outcome: Provide a repeatable benchmark and distinguish measurements from estimates.
- Focused validation: Record image digest, hardware, cold/warm build time, image size, idle CPU/RAM and available power measurements; avoid downloading models unless explicitly configured.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## EFF-02 — Isolate expensive compilation from service edits

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: EFF-01, REP-01; provisioned image builder
- Exact write set: `Dockerfile`, `scripts/build_llama_cpp_from_source.sh`, `.dockerignore`
- Primary integration lock: image-build
- Outcome: Reorder or stage build artifacts, use shallow pinned source retrieval, and exclude .wiki and instance env files from context.
- Focused validation: Compare cold/warm builds using the baseline; change only a service script and inspect cache reuse; verify binary and backend loading; bound build concurrency.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## EFF-03 — Cache and cancel redundant CI builds

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: TST-02
- Exact write set: `.github/workflows/container.yml`
- Primary integration lock: ci-workflow
- Outcome: Add scoped cache reuse and concurrency cancellation.
- Focused validation: Inspect BuildKit cache hits across two test builds and confirm superseded PR runs cancel without canceling protected release work.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## EFF-04 — Offer an explicit minimal service preset

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: EFF-01, PRT-02; accessible benchmark Docker host
- Exact write set: `compose.minimal.yaml`, `docs/performance.md`, `README.md`
- Primary integration lock: runtime-docs
- Outcome: Provide an opt-in lower-resource preset and tuning guidance for context size, batch size and parallelism.
- Focused validation: Render the preset, measure idle resources and verify inference plus seeded client behavior with optional services disabled.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

