# Parallel execution guide

This is a scheduling reference, not authorization to start agents or product changes. Schedule only phases whose prerequisites and validation resources are available. Hold one primary integration lock per phase and never overlap exact file write sets, even when primary locks differ. README, Dockerfile, Makefile, CI, and wiki reconciliation are common conflict surfaces. Serialize portfolio updates after each handoff.

## High impact implementation queue

Updated 2026-10-31. Docker Desktop and an Apple Silicon host are available. The pinned ARM64 INDIGO image builds, and the qualified Qwen3 MLX contract passes clean routed streaming plus a structured tool-result round trip. Full ARM64 health still fails on the inherited x86-64 code-server bundle. The latest published Linux CI run builds the pinned CPU image and passes content, lifecycle, and both bundled MCP protocol checks. Do not treat build or router liveness as model-serving acceptance.

1. Coordinate the upstream architecture fix and release in PLT-05, then complete PLT-03 with the qualified Qwen3 contract, OpenCode selection and restart/preservation evidence. Only then start UZU-01; its later phases follow in order.
2. Serialize the now-ready REP-02 and REP-04 image-build work; EFF-03 may use the released CI lock. Run DAT-01 and CFG-02 when their specific fixtures are available. NET-02 requires a private OpenViking 0.4.17 auth fixture with a tenant user key. Keep overlapping Dockerfile, CI and dependency-update documentation edits serial.
3. Run TST-03 when an approved small model fixture and CPU host are available; its report must mark GPU inference unverified. DAT-02 follows DAT-01 and requires a separate disposable restore rehearsal. Recheck each phase's code baseline, exact write set, and five-hour budget before starting it.

The next implementation handoff for each phase is its plan's `Outcome` and `Focused validation` pair. At completion, remove that phase, update the nearest index, network and this guide, and retain durable evidence in code, tests or user documentation.

| Plan and phase | Primary lock | Eligibility |
| --- | --- | --- |
| [NET-02](openviking-access.md) | openviking-access | Blocked: Docker host, private auth config and tenant user key |
| [CFG-02](safe-config-rendering.md) | mcp-launchers | Blocked: provisioned image or Docker host for live MCP validation |
| [REP-02](reproducible-builds.md) | image-build | Ready: registries and provisioned builder are available |
| [REP-04](reproducible-builds.md) | image-build | Ready after REP-02 releases the shared image-build lock |
| [TST-03](runtime-ci.md) | inference-validation | Blocked: approved small model fixture and CPU host |
| [DAT-01](persistent-state.md) | standalone-launch | Blocked: Docker host with disposable container and volume |
| [DAT-02](persistent-state.md) | runtime-docs | Blocked: DAT-01 and Docker host with disposable restore volumes |
| [PLT-02](platform-contract.md) | image-build | Blocked: approved CPU model fixture; builder is available |
| [PLT-03](platform-contract.md) | mac-inference-validation | Blocked: PLT-05; qualified Qwen3 fixture and routed protocol evidence are available |
| [PLT-05](platform-contract.md) | image-build | Blocked: upstream Gold/my-shell-setup write and Notebook release access |
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
| [EFF-02](build-and-runtime-efficiency.md) | image-build | EFF-01; provisioned image builder |
| [EFF-03](build-and-runtime-efficiency.md) | ci-workflow | Ready: runtime CI baseline is green |
| [EFF-04](build-and-runtime-efficiency.md) | runtime-docs | EFF-01, PRT-02; accessible benchmark Docker host |

Medium-impact PRT-02, ENV-01 and DOC-01 remain eligible in the wider portfolio. PRT-01 and ENV-01 remain ordered.

