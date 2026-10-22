# Parallel execution guide

This is a scheduling reference, not authorization to start agents or product changes. Schedule only phases whose prerequisites and validation resources are available. Hold one primary integration lock per phase and never overlap exact file write sets, even when primary locks differ. README/Dockerfile/CI and wiki reconciliation are common conflict surfaces. Serialize portfolio updates after each handoff.

| Plan and phase | Primary lock | Eligibility |
| --- | --- | --- |
| [HLT-01](plans/health-budget.md) | health-contract | Ready once validation tools/fixtures are available |
| [NET-01](plans/openviking-access.md) | runtime-docs | Ready once validation tools/fixtures are available |
| [NET-02](plans/openviking-access.md) | openviking-access | NET-01; accessible Docker host and supported OpenViking auth configuration fixture |
| [CFG-01](plans/safe-config-rendering.md) | config-seeding | Ready once validation tools/fixtures are available |
| [CFG-02](plans/safe-config-rendering.md) | mcp-launchers | Ready once validation tools/fixtures are available |
| [REP-01](plans/reproducible-builds.md) | image-build | Ready once validation tools/fixtures are available |
| [REP-02](plans/reproducible-builds.md) | image-build | REP-01; access to upstream registries and a provisioned image builder |
| [TST-01](plans/runtime-ci.md) | ci-workflow | Ready once validation tools/fixtures are available |
| [TST-02](plans/runtime-ci.md) | ci-workflow | TST-01; accessible Docker runner and prebuilt image |
| [TST-03](plans/runtime-ci.md) | inference-validation | TST-02; approved model fixture and available CPU/GPU validation hosts |
| [DAT-01](plans/persistent-state.md) | standalone-launch | Ready once validation tools/fixtures are available |
| [DAT-02](plans/persistent-state.md) | runtime-docs | Accessible Docker host with disposable test volumes |
| [PLT-01](plans/platform-contract.md) | standalone-launch | Ready once validation tools/fixtures are available |
| [PLT-02](plans/platform-contract.md) | image-build | REP-01; provisioned builder and approved CPU model fixture |
| [DOC-01](plans/docs-onboarding.md) | runtime-docs | Ready once validation tools/fixtures are available |
| [ENV-01](plans/environment-validation.md) | environment-contract | Ready once validation tools/fixtures are available |
| [ENV-02](plans/environment-validation.md) | environment-contract | ENV-01 |
| [PRT-01](plans/port-and-agent-contracts.md) | environment-contract | ENV-01 |
| [PRT-02](plans/port-and-agent-contracts.md) | config-seeding | CFG-01 |
| [EFF-01](plans/build-and-runtime-efficiency.md) | performance-evidence | Accessible benchmark Docker host and fixed image input revisions |
| [EFF-02](plans/build-and-runtime-efficiency.md) | image-build | EFF-01, REP-01; provisioned image builder |
| [EFF-03](plans/build-and-runtime-efficiency.md) | ci-workflow | TST-02 |
| [EFF-04](plans/build-and-runtime-efficiency.md) | runtime-docs | EFF-01, PRT-02; accessible benchmark Docker host |

Initially independent candidates include HLT-01, CFG-01, ENV-01 and DOC-01, subject to exact write-set checks. REP-01 also touches Dockerfile, so it cannot overlap HLT-01. PRT-01 and ENV-01 share validation code and are ordered explicitly. EFF-03 and TST phases serialize through the CI lock.

