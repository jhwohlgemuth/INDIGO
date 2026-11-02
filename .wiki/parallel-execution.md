# Parallel execution guide

This is a scheduling reference, not authorization to start agents or product changes. Schedule only phases whose prerequisites and validation resources are available. Hold one primary integration lock per phase and never overlap exact file write sets, even when primary locks differ. README, Dockerfile, Makefile, CI, and wiki reconciliation are common conflict surfaces. Serialize portfolio updates after each handoff.

## High impact implementation queue

Updated 2026-11-02. Docker Desktop and an Apple Silicon host are available. The pinned ARM64 INDIGO image builds, and the qualified Qwen3 MLX path passes routed streaming, a structured tool-result round trip, default OpenCode selection, and restart preservation. The local pinned code-server overlay restores full ARM64 runtime health. The latest published Linux CI run builds the pinned CPU image and passes content, lifecycle, and both bundled MCP protocol checks. Do not treat build or router liveness as model-serving acceptance.

1. No phase is implementation-ready. NET-02 requires a private OpenViking 0.4.17 auth fixture with a tenant user key. Keep overlapping Dockerfile, CI and dependency-update documentation edits serial.
2. Run UZU-01 when a usable Uzu-format checkpoint and upstream source/toolchain are available; use the recorded MLX result as its comparison baseline. Its later phases follow in order.
3. Run TST-03 when an approved small model fixture and CPU host are available; its report must mark GPU inference unverified. Recheck each phase's code baseline, exact write set, and five-hour budget before starting it.

The next implementation handoff for each phase is its plan's `Outcome` and `Focused validation` pair. At completion, remove that phase, update the nearest index, network and this guide, and retain durable evidence in code, tests or user documentation.

| Plan and phase | Primary lock | Eligibility |
| --- | --- | --- |
| [NET-02](openviking-access.md) | openviking-access | Blocked: Docker host, private auth config and tenant user key |
| [TST-03](runtime-ci.md) | inference-validation | Blocked: approved small model fixture and CPU host |
| [PLT-02](platform-contract.md) | image-build | Blocked: approved CPU model fixture; builder is available |
| [UZU-01](uzu-support.md) | mac-inference-validation | Blocked: usable Uzu checkpoint and upstream source/toolchain; MLX baseline and Apple Silicon host are available |
| [UZU-02](uzu-support.md) | mac-host-runtime | UZU-01 and recorded source/toolchain/checkpoint contract |
| [UZU-03](uzu-support.md) | router-config-seeding | UZU-02 |
| [UZU-04](uzu-support.md) | mac-mode-orchestration | UZU-03 |
| [UZU-05](uzu-support.md) | mac-inference-validation | UZU-04 and qualified Mac host/checkpoint |
| [EFF-03](build-and-runtime-efficiency.md) | ci-workflow | Blocked: no authenticated test-PR permission; recent hosted runs do not provide a successful cache pair or cancellation evidence |

