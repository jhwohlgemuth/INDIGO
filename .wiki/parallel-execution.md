# Parallel execution guide

This is a scheduling reference, not authorization to start agents or product changes. Schedule only phases whose prerequisites and validation resources are available. Hold one primary integration lock per phase and never overlap exact file write sets, even when primary locks differ. README, Dockerfile, Makefile, CI, and wiki reconciliation are common conflict surfaces. Serialize portfolio updates after each handoff.

## High impact implementation queue

Updated 2026-10-27. Docker Desktop and an Apple Silicon host are available. The pinned ARM64 INDIGO image builds, but the local runtime smoke fails code-server health and routed MLX emits malformed streamed and tool-call responses. The latest published Linux CI run passes shell checks and lint, then loses the hosted runner during the full image build; a lighter CPU validation build and runner disk cleanup await a new CI result. Do not treat build or router liveness as model-serving acceptance.

1. Run the lighter CPU validation image on Linux CI, repair any remaining image or startup failure, then complete TST-02's MCP check. The tool download and shell/lint phases passed in the previous Linux run and were pruned.
2. Repair the MLX server/checkpoint output contract in PLT-04 and the inherited ARM64 code-server bundle in PLT-05. Then complete PLT-03 with clean streaming, a tool-result round trip, OpenCode selection and restart evidence. Only then start UZU-01; its later phases follow in order.
3. Use the available Docker builder for REP-01 before PLT-02 or the remaining REP-02 bases; run REP-04, DAT-01, and CFG-02 when their specific fixtures are available. NET-02 requires a private OpenViking 0.4.17 auth fixture with a tenant user key. Keep overlapping Dockerfile, CI and dependency-update documentation edits serial.
4. Run TST-03 only after TST-02 and an approved small model fixture on a CPU host; its report must mark GPU inference unverified. DAT-02 follows DAT-01 and requires a separate disposable restore rehearsal. Recheck each phase's code baseline, exact write set, and five-hour budget before starting it.

The next implementation handoff for each phase is its plan's `Outcome` and `Focused validation` pair. At completion, remove that phase, update the nearest index, network and this guide, and retain durable evidence in code, tests or user documentation.

| Plan and phase | Primary lock | Eligibility |
| --- | --- | --- |
| [NET-02](openviking-access.md) | openviking-access | Blocked: Docker host, private auth config and tenant user key |
| [CFG-02](safe-config-rendering.md) | mcp-launchers | Blocked: provisioned image or Docker host for live MCP validation |
| [REP-01](reproducible-builds.md) | image-build | Ready: ARM64 builder and upstream source access available |
| [REP-02](reproducible-builds.md) | image-build | Blocked: REP-01, registries and provisioned builder |
| [REP-04](reproducible-builds.md) | image-build | Blocked: Homebrew sources and provisioned builder |
| [TST-02](runtime-ci.md) | ci-workflow | In progress; Linux CPU image and startup CI result pending |
| [TST-03](runtime-ci.md) | inference-validation | Blocked: TST-02, approved small model fixture and CPU host |
| [DAT-01](persistent-state.md) | standalone-launch | Blocked: Docker host with disposable container and volume |
| [DAT-02](persistent-state.md) | runtime-docs | Blocked: DAT-01 and Docker host with disposable restore volumes |
| [PLT-02](platform-contract.md) | image-build | Blocked: REP-01, builder and approved CPU model fixture |
| [PLT-03](platform-contract.md) | mac-inference-validation | Blocked: PLT-04 and PLT-05 after failed routed acceptance |
| [PLT-04](platform-contract.md) | mac-inference-validation | Ready: Apple Silicon host and failing checkpoint fixture available |
| [PLT-05](platform-contract.md) | image-build | Blocked: Notebook ARM64 build/release access |
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

