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

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `scripts/check.sh` accepts any nonempty value for most required fields. Numeric ports are evaluated in Bash arithmetic, where leading zeros can imply octal. `scripts/new.sh` defaults to +1, which can overlap adjacent ports of the base instance; it does not compare derived ports against base_ports. lsof availability gates host checks, occupied ports only warn, and output is written before final validation.

## Boundaries and decisions

Define a strict common .env subset for Make, Compose and scripts. Reject unsupported syntax rather than sourcing untrusted files. Make base-instance collisions errors and live-host checks explicit best-effort diagnostics. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Malformed, duplicate, leading-zero and out-of-range fixtures have deliberate outcomes; generation rejects base/new overlaps and never replaces an existing file on failed validation.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## ENV-01 — Validate the shared environment grammar

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `scripts/check.sh`, `tests/env-validation.sh`, `docs/environment.md`
- Primary integration lock: environment-contract
- Outcome: Return consistent actionable errors and parse decimal ports deliberately.
- Focused validation: Exercise duplicate keys, CRLF, quotes, whitespace, port 08, overflow, invalid image/host values and missing required fields; compare accepted fixtures through Compose.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## ENV-02 — Generate instance files transactionally

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: ENV-01
- Exact write set: `scripts/new.sh`, `tests/new-instance.sh`
- Primary integration lock: environment-contract
- Outcome: Validate a temporary file before atomic replacement and detect base-instance collisions.
- Focused validation: Exercise default +1 against adjacent base ports, explicit safe offsets, busy ports with/without lsof, extra arguments, force failure and retained original content.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

