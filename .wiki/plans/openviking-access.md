---
type: Plan
title: Make OpenViking host access explicit and secure
description: Default documentation describes container-only access; an authenticated opt-in mode accepts authorized host requests and rejects missing or invalid credentials.
difficulty: medium
impact: high
package: [indigo]
tags: [openviking-access, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Make OpenViking host access explicit and secure

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `compose.yaml:49` sets OpenViking to container loopback while publishing port 1933. `README.md` advertises a host endpoint; Docker port publishing normally targets the container network interface, not its loopback. The service rejects dev authentication on non-loopback addresses according to the current service wrapper. Compose hard-codes the host instead of interpolating an override.

## Boundaries and decisions

Keep dev mode container-local. Provide a separate opt-in host-access override using upstream API-key authentication; retain host-loopback publishing. Do not silently widen every service's bind address. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Default documentation describes container-only access; an authenticated opt-in mode accepts authorized host requests and rejects missing or invalid credentials.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## NET-01 — Define a truthful default access contract

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `README.md`, `ARCHITECTURE.md`
- Primary integration lock: runtime-docs
- Outcome: Document container-local dev access and the authentication requirement.
- Focused validation: Compare endpoint tables and commands against Compose and the OpenViking wrapper; verify no default host-access promise remains.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## NET-02 — Add authenticated host-access mode

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: NET-01; accessible Docker host and supported OpenViking auth configuration fixture
- Exact write set: `compose.openviking-host.yaml`, `scripts/check-openviking-auth.sh`, `tests/openviking-auth.sh`, `README.md`
- Primary integration lock: openviking-access
- Outcome: Use a mounted private configuration and fail closed before exposing the listener.
- Focused validation: Render default and override Compose; on a disposable configured container test host /health and protected API calls with absent, invalid, and valid keys; verify logs do not disclose keys.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

