# INDIGO planning portfolio

Reviewed 2026-10-22 at commit ea5c9f7cb7734f1bee302e22bfd8035a8e851fc4. This portfolio contains 11 executable plans. Sorting is impact descending, then difficulty ascending; ties favor user-visible correctness and stronger evidence. Difficulty is relative remaining engineering complexity, not elapsed duration. Every phase is capped at five active hours; larger plans have multiple phases.

| Rank | Remaining outcome | Impact | Difficulty |
| --- | --- | --- | --- |
| 1 | [Bound aggregate health checks](plans/health-budget.md) | high | low |
| 2 | [Make OpenViking host access explicit and secure](plans/openviking-access.md) | high | medium |
| 3 | [Render model and workspace paths safely](plans/safe-config-rendering.md) | high | medium |
| 4 | [Pin and verify build inputs](plans/reproducible-builds.md) | high | medium |
| 5 | [Test service behavior before releasing images](plans/runtime-ci.md) | high | medium |
| 6 | [Preserve router configuration and document recovery](plans/persistent-state.md) | high | medium |
| 7 | [Verify platform support and a genuine CPU path](plans/platform-contract.md) | high | high |
| 8 | [Make onboarding and release documentation consistent](plans/docs-onboarding.md) | medium | low |
| 9 | [Make environment validation and instance creation dependable](plans/environment-validation.md) | medium | medium |
| 10 | [Unify internal ports and generated client defaults](plans/port-and-agent-contracts.md) | medium | medium |
| 11 | [Reduce measured build and idle resource costs](plans/build-and-runtime-efficiency.md) | medium | high |

## Navigation

- [Plan directory](plans/index.md)
- [Dependency network](plan-network.md)
- [Parallel lanes and integration locks](parallel-execution.md)

## Review scope and limitations

Inspected all tracked application scripts, service definitions, image/build configuration, agent/router templates, CI and user/architecture documentation. No CodeGraph directory exists. The initial worktree was clean. Recent history includes the portability merge, user-story work and source-built inference support; recommendations account for existing CPU/isolated overrides, loopback publishing, pinned Pinokio and bounded OpenViking retries.

All four Compose combinations passed config --quiet: base, CPU, isolated, CPU plus isolated. Docker daemon access was denied, so no image build, runtime smoke test, inference benchmark or energy measurement was performed. Runtime claims derived from source are identified as such in the plans. No product code changed. Review is not a vulnerability audit or a measured performance assessment.

## Planning convention

Uses the [okf-plan-browser planning skill](https://github.com/jhwohlgemuth/okf-plan-browser/blob/main/.agents/skills/planning/SKILL.md), read on 2026-10-22 (skill blob 0b14e9d2e20632ff2abe83b844838a288bc99689). Validation used its validate_wiki.py blob cdeedab808a05e06eaf7a1663005569f35797e4d. Plans represent remaining work: preserve stable unfinished phase IDs, prune finished phases, and delete a plan plus its index/network/lane references once acceptance criteria are satisfied. Preserve durable evidence outside this wiki. At four active hours stop adding behavior and reserve the last hour for validation and handoff.

## Decisions retained for future execution

Keep the current single-container development architecture; do not undertake a microservice rewrite. Keep OpenViking dev mode container-local and make authenticated host access opt-in. Treat native ARM64 and alternative GPU backends as future scope requiring separate evidence. Treat model acquisition as ACORN-owned. Prefer opt-in resource presets until measurements justify changing defaults.

