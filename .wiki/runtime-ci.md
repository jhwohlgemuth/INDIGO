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

Rechecked 2026-10-31. The [published workflow](https://github.com/jhwohlgemuth/INDIGO/actions/runs/41264230496) at `75c4d64` passes Windows configuration and the complete Linux validation job: installation, `make check`, `make lint`, pinned CPU image build, content smoke, startup, bounded Streamable HTTP initialization and tools/list assertions for both bundled MCP services, and shutdown. The available ARM64 base retains the separate PLT-05 code-server defect. Router health is not model-serving proof, so the remaining phase is the explicit model-serving acceptance job.

## Boundaries and decisions

Keep cheap shell/config tests on every PR; install their lint tools in CI. Verify the CPU boot integration path in the existing image workflow and add a separate manually triggered real-model job. Label GPU inference unverified until separately measured.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

CI detects startup, seeding, disabled-service and shutdown regressions; a scheduled or manually triggered model test verifies a real completion without claiming GPU coverage from CPU checks.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## TST-03 — Add an explicit model-serving acceptance job

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: approved small model fixture and available CPU validation host
- Exact write set: `scripts/inference-smoke.sh`, `.github/workflows/inference.yml`, `docs/inference-validation.md`
- Primary integration lock: inference-validation
- Outcome: Add a manual CPU model-serving workflow and publish its model hash, backend, host and completion result without implying GPU coverage.
- Focused validation: Use an approved small model fixture on a provisioned CPU host; load it and request one completion; record the model hash, backend and result, and mark GPU inference unverified.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

