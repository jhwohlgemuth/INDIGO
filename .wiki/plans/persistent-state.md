---
type: Plan
title: Preserve router configuration and document recovery
description: A customized router configuration survives run-mode container recreation; documented backup restoration recovers a sample workspace, configuration and state into a separate instance.
difficulty: medium
impact: high
package: [indigo]
tags: [persistent-state, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Preserve router configuration and document recovery

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `Makefile` run mounts eight volumes but omits `/home/nonroot/.config/llama-swap`, whereas Compose persists it. The quick-start workspace is explicitly ephemeral. README lists persistent data but contains no backup/restore procedure, migration checks or restore rehearsal.

## Boundaries and decisions

Add router persistence to the fully persistent run mode. Keep quick-start behavior explicit. Back up credentials privately and exclude re-downloadable model/cache data by default. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

A customized router configuration survives run-mode container recreation; documented backup restoration recovers a sample workspace, configuration and state into a separate instance.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## DAT-01 — Persist standalone router configuration

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `Makefile`, `README.md`, `tests/run-mounts.sh`
- Primary integration lock: standalone-launch
- Outcome: Add the missing named volume and reconcile the volume count.
- Focused validation: Inspect dry-run docker arguments; on a disposable instance edit router config, recreate the container with the same volume and compare content.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## DAT-02 — Add and rehearse recovery instructions

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: Accessible Docker host with disposable test volumes
- Exact write set: `docs/backup-restore.md`, `README.md`
- Primary integration lock: runtime-docs
- Outcome: Document consistent stop/snapshot/restore steps, included paths, exclusions and rollback.
- Focused validation: Rehearse backup and restore of disposable data into a differently named instance; verify checksums, ownership and private credential permissions; never operate on existing user volumes.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

