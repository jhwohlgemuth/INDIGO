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

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `scripts/build_llama_cpp_from_source.sh:67` clones llama.cpp default HEAD without checkout. `Dockerfile:149` installs current Homebrew hf and llama-swap. Image references are mutable tags. CI downloads shfmt without checksum verification. Pinokio's source commit and npm ci already provide useful partial pinning.

## Boundaries and decisions

Start with the inference dependency; extend to reviewed immutable image/tool references with a documented update process. Do not assert bit-for-bit reproducibility while apt and transitive package resolution remain unlocked. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Inference source revision is explicit and recorded; tool downloads are verified; dependency updates have reviewable version evidence and a repeatable smoke-validation procedure.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## REP-01 — Pin the inference source revision

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `scripts/build_llama_cpp_from_source.sh`, `Dockerfile`, `tests/build-inputs.sh`
- Primary integration lock: image-build
- Outcome: Build llama.cpp from a reviewed full commit SHA and record it in image metadata.
- Focused validation: Verify invalid revisions fail, the requested commit is checked out, and the compiled binary reports the expected version on a provisioned builder.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## REP-02 — Record and verify remaining release inputs

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: REP-01; access to upstream registries and a provisioned image builder
- Exact write set: `Dockerfile`, `.github/workflows/container.yml`, `docs/dependency-updates.md`
- Primary integration lock: image-build
- Outcome: Pin supported image and tool inputs, document residual apt/pip/npm resolution risk and the update procedure.
- Focused validation: Verify checksums fail on changed bytes; inspect resolved image digests and installed tool versions; run image smoke tests after reviewed updates.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

