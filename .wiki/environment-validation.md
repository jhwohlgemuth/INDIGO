---
type: Plan
title: Make environment validation and instance creation dependable
description: Malformed, duplicate, leading-zero and out-of-range fixtures have deliberate outcomes; generation rejects base/new overlaps and never replaces an existing file on failed validation.
difficulty: medium
impact: medium
package: [indigo]
tags: [environment-validation, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Make environment validation and instance creation dependable

## Current evidence

Rechecked 2026-11-01. `scripts/check.sh` now parses the shared environment grammar in one non-evaluating pass, reports duplicate and malformed assignments, validates typed OCI/host/resource fields, accepts LF and CRLF, and canonicalizes ports explicitly in base 10 so `08` is accepted while `08`/`8` collisions fail. `tests/env-validation.sh` covers missing fields, quotes, whitespace, shell syntax, invalid image/host values, overflow and accepted Compose fixtures; `docs/environment.md` records the contract. `scripts/new.sh` still defaults to +1, can overlap adjacent base-instance ports, treats occupied host ports as warnings, and writes output before final validation.

## Boundaries and decisions

Keep the strict common `.env` subset non-evaluating across Make, Compose and scripts. The remaining phase must make generated output transactional, reject base-instance collisions, and keep live-host checks as explicit best-effort diagnostics.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Malformed, duplicate, leading-zero and out-of-range fixtures have deliberate outcomes; generation rejects base/new overlaps and never replaces an existing file on failed validation.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## ENV-02 — Generate instance files transactionally

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none; the shared environment grammar is enforced by `scripts/check.sh`
- Exact write set: `scripts/new.sh`, `tests/new-instance.sh`
- Primary integration lock: environment-contract
- Outcome: Validate a temporary file before atomic replacement and detect base-instance collisions.
- Focused validation: Exercise default +1 against adjacent base ports, explicit safe offsets, busy ports with/without lsof, extra arguments, force failure and retained original content.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

