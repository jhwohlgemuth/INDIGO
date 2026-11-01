---
type: Plan
title: Reduce measured build and idle resource costs
description: Repeatable measurements show build/cache and idle-resource benefits; the remaining evidence is GitHub-hosted cache reuse and PR cancellation behavior.
difficulty: high
impact: medium
package: [indigo]
tags: [build-and-runtime-efficiency, project-review]
status: waiting-on-validation
execution: phased
phase_budget_hours: 5
---

# Reduce measured build and idle resource costs

## Current evidence

Reviewed 2026-11-01 against commit c70dba762ef17a93c9da080a4341a6e29a864916 and the active worktree. Durable methodology and results are in `docs/performance.md`. On the controlled Dante ARM64 host, the optimized CPU build measured 328 seconds cold and 7 seconds warm versus 519 and 5 seconds at baseline; a service-only edit rebuilt in 6 seconds with inference and dependency layers cached. The final image content and CPU backend load checks pass. The opt-in minimal preset renders and starts, serves `/v1/models`, seeds disabled optional MCP entries into a fresh OpenCode volume, and averaged 4.49% Docker CPU / 354.4 MiB RAM without a loaded model versus 5.32% / 893.4 MiB for the full optional service set. Host power was unavailable, so no energy claim is made. CI now uses immutable Docker Buildx actions, a scoped GitHub Actions cache, and PR-only supersession cancellation. GitHub-hosted cache reuse across two runs and observed PR cancellation remain unverified because the workflow has not been published.

## Boundaries and decisions

Optimize measured cold/warm build time, image bytes and idle resources without removing required developer tooling. Do not claim energy savings from wall time alone. Keep the default full stack and offer the lower-resource service set as an opt-in preset.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. External validation starts only after the workflow is published to a branch.

## Acceptance criteria

Repeatable baseline and after measurements show build/cache benefits; a service-only edit avoids recompiling inference; an opt-in minimal Compose preset reduces observed idle work without breaking documented clients; hosted CI reuses the scoped cache and cancels only superseded PR work.

## Validation

Use the focused check below. If the hosted result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## EFF-03 — Cache and cancel redundant CI builds

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: Published branch containing the workflow change and permission to create or update a test PR
- Exact write set: `.github/workflows/container.yml`
- Primary integration lock: ci-workflow
- Outcome: Add scoped cache reuse and concurrency cancellation.
- Focused validation: Inspect BuildKit cache hits across two GitHub-hosted test builds; update the same test PR while a run is active and confirm the superseded PR run cancels without canceling push or manual-dispatch work.
- Handoff: Record the hosted run links in durable release/CI evidence, remove this phase and plan when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record the exact run and next action.
