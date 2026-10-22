---
type: Plan
title: Bound aggregate health checks
description: Every enabled endpoint produces a result within the Docker deadline, disabled services are omitted, and unconfigured OpenViking remains WAIT.
difficulty: low
impact: high
package: [indigo]
tags: [health-budget, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Bound aggregate health checks

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `scripts/healthcheck.sh` probes up to ten endpoints sequentially with a five-second timeout each. `Dockerfile:161` gives the whole check only 30 seconds, so failures can prevent later results from being reported. The five-minute interval and ten-second startup allowance also deserve measurement.

## Boundaries and decisions

Keep health checks lightweight; do not load a model on every health poll. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Every enabled endpoint produces a result within the Docker deadline, disabled services are omitted, and unconfigured OpenViking remains WAIT.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## HLT-01 — Make health checks finish within their deadline

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `scripts/healthcheck.sh`, `Dockerfile`, `tests/healthcheck.sh`
- Primary integration lock: health-contract
- Outcome: Bound parallel probes or a shared deadline while preserving deterministic output and a nonzero failure result.
- Focused validation: Stub curl with fast successes and delayed failures; exercise every service flag and WAIT; assert total elapsed time below 30 seconds.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

