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

Rechecked 2026-10-22 at commit db2c536517837492b31007cf86688ec6b7e23fa3 with local changes. `compose.yaml:49` sets OpenViking to container loopback while publishing port 1933. `README.md` and `ARCHITECTURE.md` now explain that default host publishing cannot reach this listener and host access needs a separate authenticated override. The service rejects dev authentication on non-loopback addresses. The pinned OpenViking 0.4.17 [authentication guide](https://github.com/volcengine/OpenViking/blob/v0.4.17/docs/en/guides/04-authentication.md) specifies `server.auth_mode: api_key`, a nonempty `server.root_api_key`, and a user key for data APIs.

## Boundaries and decisions

Keep dev mode container-local. Provide a separate Compose override that binds only OpenViking to the container network interface, keeps host publishing on loopback, and mounts a private `ov.conf` read-only. The service wrapper must refuse a non-loopback bind unless the config explicitly selects `api_key` with a nonempty root key. Use a disposable tenant user key to validate data access; `/health` alone is not an auth test. No Docker daemon was available for runtime verification.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Default documentation describes container-only access; an authenticated opt-in mode accepts authorized host requests and rejects missing or invalid credentials.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## NET-02 — Add authenticated host-access mode

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: accessible Docker host and disposable OpenViking 0.4.17 config with root and tenant user keys
- Exact write set: `compose.openviking-host.yaml`, `rootfs/etc/services.d/openviking/run`, `tests/openviking-auth.sh`, `README.md`
- Primary integration lock: openviking-access
- Outcome: Require `OPENVIKING_AUTH_CONFIG_PATH` for a read-only config mount, set `OPENVIKING_SERVER_HOST=0.0.0.0` only in the override, and fail closed on missing or invalid authentication configuration.
- Focused validation: Render default and override Compose; verify the default host route cannot connect. On a disposable configured container, test host `/health` and a protected data API with absent, invalid, and tenant user keys; verify logs do not disclose keys.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

