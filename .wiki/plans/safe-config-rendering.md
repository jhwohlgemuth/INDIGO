---
type: Plan
title: Render model and workspace paths safely
description: Paths with spaces, pipes, ampersands, backslashes, apostrophes and dollar signs are handled literally or rejected before writing; seeded files parse; failed seeding leaves no target; a second run preserves existing files.
difficulty: medium
impact: high
package: [indigo]
tags: [safe-config-rendering, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Render model and workspace paths safely

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `rootfs/etc/cont-init.d/20-indigo-agent-config:30` escapes ampersands but not the sed delimiter or backslashes. A path containing `|` can break rendering. `config/llama-swap/config.yaml` places the model path unquoted in a command; spaces change argument boundaries. Both MCP run scripts interpolate workspace paths into command strings. A failed render can leave a partial target that subsequent boots preserve.

## Boundaries and decisions

Use format-aware serialization and correct command-argument encoding, with temporary-file validation and atomic rename. Do not execute arbitrary path content. Preserve existing user files. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Paths with spaces, pipes, ampersands, backslashes, apostrophes and dollar signs are handled literally or rejected before writing; seeded files parse; failed seeding leaves no target; a second run preserves existing files.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## CFG-01 — Make model configuration seeding atomic and literal

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `rootfs/etc/cont-init.d/20-indigo-agent-config`, `config/llama-swap/config.yaml`, `tests/config-seeding.sh`
- Primary integration lock: config-seeding
- Outcome: Produce valid router commands without partial configuration files.
- Focused validation: Run seeding against temporary HOME with hostile and ordinary path fixtures; parse output and inspect actual llama-server argv through a stub; repeat to prove idempotency.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## CFG-02 — Preserve workspace argument boundaries for MCP

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `rootfs/etc/services.d/mcp-filesystem/run`, `rootfs/etc/services.d/mcp-rust-analyzer/run`, `tests/mcp-paths.sh`
- Primary integration lock: mcp-launchers
- Outcome: Pass one literal workspace argument to each child, using the gateway's verified launch semantics.
- Focused validation: Capture child argv using a fake gateway/child; test spaces and shell metacharacters; on a provisioned image perform MCP initialization and list tools.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

