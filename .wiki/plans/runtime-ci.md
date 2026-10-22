---
type: Plan
title: Test service behavior before releasing images
description: CI detects startup, seeding, disabled-service and shutdown regressions; a scheduled or manually triggered model test verifies a real completion without claiming GPU coverage from CPU checks.
difficulty: medium
impact: high
package: [indigo]
tags: [runtime-ci, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Test service behavior before releasing images

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `.github/workflows/container.yml` runs make check, make build and make image-smoke. The smoke target checks executable/config presence through an overridden entrypoint, so it never boots /init. make lint is not called in Linux CI. There are no tracked behavioral test files. Architecture documentation correctly notes that router health is not proof of inference.

## Boundaries and decisions

Keep cheap shell/config tests on every PR; add a CPU boot integration path and a separate opt-in real-model acceptance job. Hardware and model downloads are external prerequisites. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

CI detects startup, seeding, disabled-service and shutdown regressions; a scheduled or manually triggered model test verifies a real completion without claiming GPU coverage from CPU checks.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## TST-01 — Run shell behavior and lint checks in CI

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `tests/service-contracts.sh`, `.github/workflows/container.yml`, `Makefile`
- Primary integration lock: ci-workflow
- Outcome: Catch cheap contract regressions without building an image first.
- Focused validation: Use fixtures for enable flags, missing/invalid OpenViking config and bounded retries; run shellcheck, shfmt, hadolint, yamllint and all four Compose renderings.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## TST-02 — Boot and stop a disposable CPU container in CI

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: TST-01; accessible Docker runner and prebuilt image
- Exact write set: `scripts/runtime-smoke.sh`, `.github/workflows/container.yml`, `Makefile`
- Primary integration lock: ci-workflow
- Outcome: Verify real service lifecycle with a bounded CI timeout.
- Focused validation: Boot through /init, inspect health, execute MCP initialization/list-tools, stop within the configured grace period and collect failure logs; always clean only test-owned resources.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## TST-03 — Add an explicit model-serving acceptance job

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: TST-02; approved model fixture and available CPU/GPU validation hosts
- Exact write set: `scripts/inference-smoke.sh`, `.github/workflows/inference.yml`, `docs/inference-validation.md`
- Primary integration lock: inference-validation
- Outcome: Publish truthful model/backend compatibility evidence.
- Focused validation: Use an approved small model fixture; load it and request one completion; record model hash, backend and result; validate CPU and GPU on separate provisioned hosts.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

