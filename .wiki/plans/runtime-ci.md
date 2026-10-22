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

Rechecked 2026-10-22 at commit db2c536517837492b31007cf86688ec6b7e23fa3 with local changes. `.github/workflows/container.yml` now installs lint tools and runs `make check` and `make lint` before image build. `tests/service-contracts.sh` checks disabled-service flags, missing OpenViking config, bounded retry and server arguments; Makefile includes shell tests. The image smoke target still checks executable/config presence through an overridden entrypoint, so it never boots /init. Architecture documentation correctly notes that router health is not proof of inference.

## Boundaries and decisions

Keep cheap shell/config tests on every PR; install their lint tools in CI. Add a CPU boot integration path in the existing image workflow and a separate manually triggered real-model job. Label GPU inference unverified until separately measured. No local Docker daemon was available.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

CI detects startup, seeding, disabled-service and shutdown regressions; a scheduled or manually triggered model test verifies a real completion without claiming GPU coverage from CPU checks.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## TST-01 — Run shell behavior and lint checks in CI

- Status: in-progress
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `tests/service-contracts.sh`, `.github/workflows/container.yml`, `Makefile`
- Primary integration lock: ci-workflow
- Outcome: Install required lint tools and run `make check`, `make lint`, and fixture-based service contract tests before image build in Linux CI.
- Focused validation: Use fixtures for enable flags, missing/invalid OpenViking config and bounded retries; run shellcheck, shfmt, hadolint, yamllint and all four Compose renderings.
- Handoff: `tests/service-contracts.sh`, `.github/workflows/container.yml` and `Makefile` changed. Local service fixtures, `make check` and `make lint` passed, including shellcheck, shfmt, hadolint, yamllint and all four Compose renderings. Review the Linux workflow result, repair any focused defect, then remove TST-01 and reconcile the wiki.

## TST-02 — Boot and stop a disposable CPU container in CI

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: TST-01; GitHub Actions Docker runner and image built by the workflow
- Exact write set: `scripts/runtime-smoke.sh`, `.github/workflows/container.yml`, `Makefile`
- Primary integration lock: ci-workflow
- Outcome: Verify real service lifecycle with a bounded CI timeout.
- Focused validation: Boot through /init, inspect health, execute MCP initialization/list-tools, stop within the configured grace period and collect failure logs; always clean only test-owned resources.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## TST-03 — Add an explicit model-serving acceptance job

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: TST-02; approved small model fixture and available CPU validation host
- Exact write set: `scripts/inference-smoke.sh`, `.github/workflows/inference.yml`, `docs/inference-validation.md`
- Primary integration lock: inference-validation
- Outcome: Add a manual CPU model-serving workflow and publish its model hash, backend, host and completion result without implying GPU coverage.
- Focused validation: Use an approved small model fixture on a provisioned CPU host; load it and request one completion; record the model hash, backend and result, and mark GPU inference unverified.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

