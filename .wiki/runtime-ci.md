---
type: Plan
title: Test service behavior before releasing images
description: CI detects startup, seeding, disabled-service and shutdown regressions; a scheduled or manually triggered model test verifies a real completion without claiming GPU coverage from CPU checks.
difficulty: medium
impact: high
package: [indigo]
tags: [runtime-ci, project-review]
status: in-progress
execution: phased
phase_budget_hours: 5
---

# Test service behavior before releasing images

## Current evidence

Rechecked 2026-10-27 at commit 687a306. The [published Linux CI run](https://github.com/jhwohlgemuth/INDIGO/actions/runs/40573556693) passed installation, `make check`, and `make lint`, then lost the hosted runner while building the full image. Windows configuration passed. The workflow now builds a CPU validation image with bounded llama.cpp compilation and frees unused runner toolchains before build; its new Linux result is pending. The startup smoke boots `/init` in a disposable container and checks full health, seeded config, and shutdown. A local pinned ARM64 run failed because the inherited code-server bundle contains an x86-64 Node binary. Router health is not model-serving proof.

## Boundaries and decisions

Keep cheap shell/config tests on every PR; install their lint tools in CI. Verify the CPU boot integration path in the existing image workflow and add a separate manually triggered real-model job. Label GPU inference unverified until separately measured.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

CI detects startup, seeding, disabled-service and shutdown regressions; a scheduled or manually triggered model test verifies a real completion without claiming GPU coverage from CPU checks.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## TST-02 — Boot and stop a disposable CPU container in CI

- Status: in-progress
- Budget: 5 active hours maximum
- Prerequisites: GitHub Actions Docker runner and image built by the workflow
- Exact write set: `scripts/runtime-smoke.sh`, `.github/workflows/container.yml`, `Makefile`
- Primary integration lock: ci-workflow
- Outcome: Verify real service lifecycle with a bounded CI timeout.
- Focused validation: Boot through /init, inspect health, execute MCP initialization/list-tools, stop within the configured grace period and collect failure logs; always clean only test-owned resources.
- Handoff: `scripts/runtime-smoke.sh`, the Make target, and the Linux workflow step are added. A local CPU image build and content smoke pass; the ARM64 runtime smoke fails only code-server health, tracked by PLT-05. Keep this phase until the Linux amd64 workflow passes image build, startup, shutdown, and the remaining MCP initialization/list-tools check.

## TST-03 — Add an explicit model-serving acceptance job

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: TST-02; approved small model fixture and available CPU validation host
- Exact write set: `scripts/inference-smoke.sh`, `.github/workflows/inference.yml`, `docs/inference-validation.md`
- Primary integration lock: inference-validation
- Outcome: Add a manual CPU model-serving workflow and publish its model hash, backend, host and completion result without implying GPU coverage.
- Focused validation: Use an approved small model fixture on a provisioned CPU host; load it and request one completion; record the model hash, backend and result, and mark GPU inference unverified.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

