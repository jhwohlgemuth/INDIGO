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

Rechecked 2026-10-22 at commit db2c536517837492b31007cf86688ec6b7e23fa3 with local changes. Model paths now accept only `^/[A-Za-z0-9._/-]+$` before writes. Router and agent defaults publish through validated temporary files without replacing existing files or symlinks. `tests/config-seeding.sh` covers hostile paths, parsed YAML/JSON, command arguments, failed seeding and repeated runs. Both MCP run scripts still interpolate workspace paths into command strings. The pinned Supergateway 3.4.3 [launches `--stdio` through a shell](https://github.com/supercorp-ai/supergateway/blob/v3.4.3/src/gateways/stdioToStatelessStreamableHttp.ts).

## Boundaries and decisions

Accept model paths only when they match `^/[A-Za-z0-9._/-]+$`; reject spaces and shell metacharacters before any write. Render to temporary files and rename only after successful rendering, preserving existing files and symlinks; parse generated YAML/JSON in the focused test. Keep workspace paths out of Supergateway's shell command string by launching fixed child wrappers that pass the path as one quoted argument. No Docker daemon was available for live MCP verification.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Paths with spaces, pipes, ampersands, backslashes, apostrophes and dollar signs are handled literally or rejected before writing; seeded files parse; failed seeding leaves no target; a second run preserves existing files.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## CFG-02 — Preserve workspace argument boundaries for MCP

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: provisioned image or Docker host for live MCP initialization and list-tools validation
- Exact write set: `rootfs/etc/services.d/mcp-filesystem/run`, `rootfs/etc/services.d/mcp-filesystem/child`, `rootfs/etc/services.d/mcp-rust-analyzer/run`, `rootfs/etc/services.d/mcp-rust-analyzer/child`, `tests/mcp-paths.sh`
- Primary integration lock: mcp-launchers
- Outcome: Pass each gateway only its fixed `/etc/services.d/<service>/child` script path, and have each child pass its configured workspace as one quoted argument to the MCP binary.
- Focused validation: Capture child argv using a fake gateway/child; test spaces and shell metacharacters without command execution; on a provisioned image perform MCP initialization and list tools.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

