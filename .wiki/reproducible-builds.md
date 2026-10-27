---
type: Plan
title: Pin and verify build inputs
description: Inference source revision is explicit and recorded; tool downloads are verified; dependency updates have reviewable version evidence and a repeatable smoke-validation procedure.
difficulty: medium
impact: high
package: [indigo]
tags: [reproducible-builds, project-review]
status: in-progress
execution: phased
phase_budget_hours: 5
---

# Pin and verify build inputs

## Current evidence

Rechecked 2026-10-27. `scripts/build_llama_cpp_from_source.sh` still clones llama.cpp default HEAD without checkout, and Homebrew installs current hf and llama-swap. The direct Notebook base is pinned to the published 1.0.5 multi-platform index digest, and an ARM64 image built from it; other OCI bases remain mutable. The [latest published Linux run](https://github.com/jhwohlgemuth/INDIGO/actions/runs/40573556693) passed checkout, verified shfmt installation, shell checks and lint before losing the runner during the full image build. `docs/dependency-updates.md` records the inputs and update process. A local CPU validation image builds and passes content smoke; Linux CI validation is pending.

## Boundaries and decisions

Start with the inference dependency: select a reviewed full upstream commit, pass it as a Docker build argument, check it out detached, and label the built image with the revision. Handle remaining OCI base images and Homebrew version guards in separate phases with a shared update record. Do not assert bit-for-bit reproducibility while apt, Homebrew and transitive package resolution remain unlocked. An ARM64 Docker builder is available; Linux CI has not built the image successfully.

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
- Prerequisites: provisioned image builder and access to the selected upstream llama.cpp revision
- Exact write set: `scripts/build_llama_cpp_from_source.sh`, `Dockerfile`, `tests/build-inputs.sh`
- Primary integration lock: image-build
- Outcome: Use one reviewed full llama.cpp commit SHA as the default build argument, reject invalid revisions, and record the checked-out revision in image metadata.
- Focused validation: Verify invalid revisions fail, the requested commit is checked out, and the compiled binary reports the expected version on a provisioned builder.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## REP-02 — Pin OCI base image inputs

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: REP-01; access to upstream registries and a provisioned image builder
- Exact write set: `Dockerfile`, `docs/dependency-updates.md`
- Primary integration lock: image-build
- Outcome: Replace mutable `FROM` references with reviewed tag-plus-digest references and document how to review updates and the remaining apt/pip/npm resolution risk.
- Focused validation: Inspect resolved digests, build the image and run image smoke checks on a provisioned builder.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

## REP-04 — Guard Homebrew tool versions

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: access to Homebrew sources and a provisioned image builder
- Exact write set: `Dockerfile`, `docs/dependency-updates.md`
- Primary integration lock: image-build
- Outcome: Add expected-version build arguments for `hf` and `llama-swap`, fail the build on version drift, and record resolved versions and the update procedure.
- Focused validation: Build the image with expected versions, assert a mismatched expected version fails, inspect installed versions, and run image smoke checks.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

