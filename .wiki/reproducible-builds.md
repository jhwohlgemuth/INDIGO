---
type: Plan
title: Pin and verify build inputs
description: Inference source revision is explicit and recorded; tool downloads are verified; dependency updates have reviewable version evidence and a repeatable smoke-validation procedure.
difficulty: medium
impact: high
package: [indigo]
tags: [reproducible-builds, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Pin and verify build inputs

## Current evidence

Rechecked 2026-10-31. llama.cpp now defaults to the reviewed v0.8.0 commit `8642541b255bfb5dc39cd351a178be09013a55d6`, checks it out detached, rejects non-full or mismatched revisions, and records it in the image label `org.indigo.llama.cpp.revision`. `tests/build-inputs.sh` covers the contract. Real ARM64 and Linux CI CPU image builds report the expected revision and pass their focused checks. The direct Notebook base remains pinned to the published 1.0.5 multi-platform index digest; other OCI bases remain mutable, and Homebrew still installs current hf and llama-swap without version guards.

## Boundaries and decisions

Handle the remaining OCI base images and Homebrew version guards in separate phases with a shared update record. Do not assert bit-for-bit reproducibility while apt, Homebrew and transitive package resolution remain unlocked. ARM64 Docker and Linux CI builders have both built the CPU image successfully.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Inference source revision is explicit and recorded; tool downloads are verified; dependency updates have reviewable version evidence and a repeatable smoke-validation procedure.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## REP-02 — Pin OCI base image inputs

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: access to upstream registries and a provisioned image builder
- Exact write set: `Dockerfile`, `docs/dependency-updates.md`
- Primary integration lock: image-build
- Outcome: Replace mutable `FROM` references with reviewed tag-plus-digest references and document how to review updates and the remaining apt/pip/npm resolution risk.
- Focused validation: Inspect resolved digests, build the image and run image smoke checks on a provisioned builder.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## REP-04 — Guard Homebrew tool versions

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: access to Homebrew sources and a provisioned image builder
- Exact write set: `Dockerfile`, `docs/dependency-updates.md`
- Primary integration lock: image-build
- Outcome: Add expected-version build arguments for `hf` and `llama-swap`, fail the build on version drift, and record resolved versions and the update procedure.
- Focused validation: Build the image with expected versions, assert a mismatched expected version fails, inspect installed versions, and run image smoke checks.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

