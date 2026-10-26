# Parallel execution guide

This is a scheduling reference, not authorization to start agents or product changes. Schedule only phases whose prerequisites and validation resources are available. Hold one primary integration lock per phase and never overlap exact file write sets, even when primary locks differ. README, Dockerfile, Makefile, CI, and wiki reconciliation are common conflict surfaces. Serialize portfolio updates after each handoff.

## High impact implementation queue

Updated 2026-10-25 from commit e867187073fe14336eb13cc71c735be652eb5030. Health checks, model seeding, default OpenViking access documentation and standalone GPU selection passed focused local checks in the prior review. CI workflow tool verification and service contract tests passed local checks; their Linux CI result is pending. This workspace cannot access the selected Docker socket. Keep Docker-dependent phases blocked until a usable host or CI runner can execute their focused validation. Do not treat a completed dry run as runtime evidence.

1. Review the Linux CI result for REP-03 and TST-01, repair any focused defects, then prune those phases. Their local checks have passed. PRT-02 is independently ready after safe first-run seeding landed.
2. Provision a Docker image builder and disposable test resources. Then run REP-01 before PLT-02 or REP-02; run REP-04, DAT-01, and CFG-02 after their runtime fixtures are available. NET-02 requires a private OpenViking 0.4.17 auth fixture with a tenant user key. Keep overlapping README, Dockerfile, CI and dependency-update documentation edits serial.
3. Run TST-02 after TST-01 on the GitHub Actions Docker runner. Run TST-03 only after an approved small model fixture and CPU host are available; its report must mark GPU inference unverified. DAT-02 follows DAT-01 and requires a separate disposable restore rehearsal. Recheck each phase's code baseline, exact write set, and five-hour budget before starting it.
4. On an Apple Silicon Mac with Docker and an approved model, run PLT-03 and record routed MLX completion plus tool-call evidence. Only then start UZU-01; its later phases follow in order. Keep Uzu opt-in and do not announce support before UZU-05 passes.

The next implementation handoff for each phase is its plan's `Outcome` and `Focused validation` pair. At completion, remove that phase, update the nearest index, network and this guide, and retain durable evidence in code, tests or user documentation.

| Plan and phase | Primary lock | Eligibility |
| --- | --- | --- |
| [NET-02](openviking-access.md) | openviking-access | Blocked: Docker host, private auth config and tenant user key |
| [CFG-02](safe-config-rendering.md) | mcp-launchers | Blocked: provisioned image or Docker host for live MCP validation |
| [REP-01](reproducible-builds.md) | image-build | Blocked: provisioned builder and upstream revision access |
| [REP-02](reproducible-builds.md) | image-build | Blocked: REP-01, registries and provisioned builder |
| [REP-03](reproducible-builds.md) | ci-workflow | In progress; Linux CI result pending |
| [REP-04](reproducible-builds.md) | image-build | Blocked: Homebrew sources and provisioned builder |
| [TST-01](runtime-ci.md) | ci-workflow | In progress; Linux CI result pending |
| [TST-02](runtime-ci.md) | ci-workflow | TST-01; GitHub Actions Docker runner and built image |
| [TST-03](runtime-ci.md) | inference-validation | Blocked: TST-02, approved small model fixture and CPU host |
| [DAT-01](persistent-state.md) | standalone-launch | Blocked: Docker host with disposable container and volume |
| [DAT-02](persistent-state.md) | runtime-docs | Blocked: DAT-01 and Docker host with disposable restore volumes |
| [PLT-02](platform-contract.md) | image-build | Blocked: REP-01, builder and approved CPU model fixture |
| [PLT-03](platform-contract.md) | mac-inference-validation | Blocked: Apple Silicon Docker host, ARM64 base image and approved MLX model |
| [UZU-01](uzu-support.md) | mac-inference-validation | Blocked: PLT-03, Apple Silicon host, usable Uzu checkpoint and upstream source/toolchain |
| [UZU-02](uzu-support.md) | mac-host-runtime | UZU-01 and recorded source/toolchain/checkpoint contract |
| [UZU-03](uzu-support.md) | router-config-seeding | UZU-02 |
| [UZU-04](uzu-support.md) | mac-mode-orchestration | UZU-03 |
| [UZU-05](uzu-support.md) | mac-inference-validation | UZU-04 and qualified Mac host/checkpoint |
| [DOC-01](docs-onboarding.md) | runtime-docs | Ready once validation tools/fixtures are available |
| [ENV-01](environment-validation.md) | environment-contract | Ready once validation tools/fixtures are available |
| [ENV-02](environment-validation.md) | environment-contract | ENV-01 |
| [PRT-01](port-and-agent-contracts.md) | environment-contract | ENV-01 |
| [PRT-02](port-and-agent-contracts.md) | config-seeding | Ready; local config seeding fixtures |
| [EFF-01](build-and-runtime-efficiency.md) | performance-evidence | Accessible benchmark Docker host and fixed image input revisions |
| [EFF-02](build-and-runtime-efficiency.md) | image-build | EFF-01, REP-01; provisioned image builder |
| [EFF-03](build-and-runtime-efficiency.md) | ci-workflow | TST-02 |
| [EFF-04](build-and-runtime-efficiency.md) | runtime-docs | EFF-01, PRT-02; accessible benchmark Docker host |

Medium-impact PRT-02, ENV-01 and DOC-01 remain eligible in the wider portfolio. PRT-01 and ENV-01 remain ordered; EFF-03 and TST phases serialize through the CI lock.

