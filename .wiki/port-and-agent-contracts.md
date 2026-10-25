---
type: Plan
title: Unify internal ports and generated client defaults
description: Changing a supported host port keeps routing valid; unsupported internal port changes fail with a useful explanation; direct-image clients do not try disabled MCP services by default.
difficulty: medium
impact: medium
package: [indigo]
tags: [port-and-agent-contracts, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Unify internal ports and generated client defaults

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4 with local changes. Compose allows LLAMA_ARG_PORT to vary, but its published target stays 10732 and bundled OpenCode baseURL stays 10732. Router YAML also contains 10732. Direct-image optional services default off while OpenCode MCP entries default enabled. Make run hard-codes service enablement and duplicates Compose's configuration surface. First-run config seeding now preserves existing files and symlinks.

## Boundaries and decisions

Standardize internal inference on 10732 for the supported deployment and expose host-port customization separately; reject unsupported internal overrides in supported wrappers. Generate first-run MCP enablement from actual service flags while preserving user-managed files. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Changing a supported host port keeps routing valid; unsupported internal port changes fail with a useful explanation; direct-image clients do not try disabled MCP services by default.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## PRT-01 — Clarify and enforce the internal-port contract

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: ENV-01
- Exact write set: `compose.yaml`, `scripts/check.sh`, `config/llama-swap/config.yaml`, `docs/environment.md`, `tests/port-contract.sh`
- Primary integration lock: environment-contract
- Outcome: Keep a single supported internal port while preserving configurable host publishing.
- Focused validation: Render alternate host ports and verify container targets and client URLs remain aligned; reject conflicting internal-port overrides.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## PRT-02 — Seed agent defaults from service enablement

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `rootfs/etc/cont-init.d/20-indigo-agent-config`, `config/agents/opencode.json`, `tests/agent-defaults.sh`
- Primary integration lock: config-seeding
- Outcome: Enable only configured optional MCP connections on first boot.
- Focused validation: Test direct-image and full-stack flag combinations; parse generated JSON; verify existing user configuration is never overwritten.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

