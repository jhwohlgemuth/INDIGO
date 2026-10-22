---
type: Plan
title: Make onboarding and release documentation consistent
description: Version references agree or clearly describe different version domains; a fresh user can find model acquisition/import, service readiness and first-response steps; docs distinguish container started, router live and model usable.
difficulty: low
impact: medium
package: [indigo]
tags: [docs-onboarding, project-review]
status: planned
execution: phased
phase_budget_hours: 5
---

# Make onboarding and release documentation consistent

## Current evidence

Reviewed 2026-10-22 against commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. `Kitfile:5` declares 0.1.2 while README quick-start uses 0.1.4. The README covers many modes before explaining model acquisition; bundled commands use --offline and assume model files exist. It says both generators abort on port collisions, while new.sh only warns about occupied host ports. The default OpenCode template enables MCP entries even when direct-image services are off.

## Boundaries and decisions

Make a short path from prerequisites to a verified first model response, then link advanced deployment and troubleshooting pages. Do not take model ownership away from ACORN. This is remaining work, not an implementation claim. Docker runtime behavior and performance were not verified during this review because daemon access was denied.

## Dependencies

Phase prerequisites below are the authoritative blockers. Shared integration locks serialize edits but do not create feature dependencies. Every implementation phase also requires its listed validation tools and disposable fixtures to be available before starting; download and queue time are external waiting.

## Acceptance criteria

Version references agree or clearly describe different version domains; a fresh user can find model acquisition/import, service readiness and first-response steps; docs distinguish container started, router live and model usable.

## Validation

Use the focused checks in each phase. Keep fixtures disposable, preserve user state, and record hardware/model/image identity for runtime evidence. If a result cannot be verified, retain the phase and name the missing evidence. No phase may grow beyond five active hours.

# Execution phases

## DOC-01 — Publish a verified first-response guide

- Status: ready
- Budget: 5 active hours maximum
- Prerequisites: none
- Exact write set: `README.md`, `Kitfile`, `docs/getting-started.md`, `docs/troubleshooting.md`
- Primary integration lock: runtime-docs
- Outcome: Correct version and collision claims, explain optional MCP defaults, and move advanced detail behind a concise onboarding route.
- Focused validation: Check every local link; compare commands against Make and Compose; dry-run the guide in a fresh test instance with an approved model fixture when available.
- Handoff: Record validation in durable tests/docs, remove this phase when satisfied, and reconcile indexes, dependencies and lanes. If incomplete, record exact changes, failure and next action; split unexpected repairs into a fresh bounded phase.

