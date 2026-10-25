# INDIGO planning portfolio

Updated 2026-10-22 from commit db2c536517837492b31007cf86688ec6b7e23fa3 with implementation changes pending Linux CI. This portfolio contains 10 executable plans, including six high impact plans. Sorting is impact descending, then difficulty ascending; ties favor user-visible correctness and stronger evidence. Difficulty is relative remaining engineering complexity, not elapsed duration. Every phase is capped at five active hours; larger plans have multiple phases.

| Rank | Remaining outcome | Impact | Difficulty |
| --- | --- | --- | --- |
| 1 | [Make OpenViking host access explicit and secure](openviking-access.md) | high | medium |
| 2 | [Render model and workspace paths safely](safe-config-rendering.md) | high | medium |
| 3 | [Pin and verify build inputs](reproducible-builds.md) | high | medium |
| 4 | [Test service behavior before releasing images](runtime-ci.md) | high | medium |
| 5 | [Preserve router configuration and document recovery](persistent-state.md) | high | medium |
| 6 | [Verify platform support and a genuine CPU path](platform-contract.md) | high | high |
| 7 | [Make onboarding and release documentation consistent](docs-onboarding.md) | medium | low |
| 8 | [Make environment validation and instance creation dependable](environment-validation.md) | medium | medium |
| 9 | [Unify internal ports and generated client defaults](port-and-agent-contracts.md) | medium | medium |
| 10 | [Reduce measured build and idle resource costs](build-and-runtime-efficiency.md) | medium | high |

## Navigation

- [Dependency network](plan-network.md)
- [Parallel lanes, integration locks, and high impact launch order](parallel-execution.md)

## Review scope and limitations

Inspected all tracked application scripts, service definitions, image/build configuration, agent/router templates, CI and user/architecture documentation. No CodeGraph directory exists. The initial worktree was clean. Recent history includes the portability merge, user-story work and source-built inference support; recommendations account for existing CPU/isolated overrides, loopback publishing, pinned Pinokio and bounded OpenViking retries. Local implementation now includes bounded parallel health checks, safe model config seeding, corrected OpenViking access documentation, standalone GPU selection, shell contract tests and pinned CI tools.

All four Compose combinations passed config --quiet during the portfolio review and local lint run: base, CPU, isolated, CPU plus isolated. The current selected Docker context is unreachable; Docker Desktop and the local socket have no running daemon. Local `make check` and `make lint` pass, but Linux CI and image/runtime validation remain pending. No inference benchmark or energy measurement was performed. High impact phases that require Docker verification are marked blocked. Runtime claims derived from source are identified as such in the plans. Review is not a vulnerability audit or a measured performance assessment.

## Planning convention

Uses the [okf-plan-browser planning skill](https://github.com/jhwohlgemuth/okf-plan-browser/blob/main/.agents/skills/planning/SKILL.md), read on 2026-10-22 (skill blob 0b14e9d2e20632ff2abe83b844838a288bc99689). Validation used its validate_wiki.py blob cdeedab808a05e06eaf7a1663005569f35797e4d. Plans represent remaining work: preserve stable unfinished phase IDs, prune finished phases, and delete a plan plus its index/network/lane references once acceptance criteria are satisfied. Preserve durable evidence outside this wiki. At four active hours stop adding behavior and reserve the last hour for validation and handoff.

## Decisions retained for future execution

Keep the current single-container development architecture; do not undertake a microservice rewrite. Keep OpenViking dev mode container-local and make authenticated host access opt-in. Treat native ARM64 and alternative GPU backends as future scope requiring separate evidence. Treat model acquisition as ACORN-owned. Prefer opt-in resource presets until measurements justify changing defaults.

