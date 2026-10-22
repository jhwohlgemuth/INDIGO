# Dependency network

Only phase prerequisites are blockers. Integration-lock conflicts require serialization, not prerequisite edges. External host, model, registry and fixture availability is required where named; waiting does not consume active budgets.

## [Bound aggregate health checks](plans/health-budget.md)

- HLT-01: No feature prerequisite.

## [Make OpenViking host access explicit and secure](plans/openviking-access.md)

- NET-01: No feature prerequisite.
- NET-02: NET-01; accessible Docker host and supported OpenViking auth configuration fixture

## [Render model and workspace paths safely](plans/safe-config-rendering.md)

- CFG-01: No feature prerequisite.
- CFG-02: No feature prerequisite.

## [Pin and verify build inputs](plans/reproducible-builds.md)

- REP-01: No feature prerequisite.
- REP-02: REP-01; access to upstream registries and a provisioned image builder

## [Test service behavior before releasing images](plans/runtime-ci.md)

- TST-01: No feature prerequisite.
- TST-02: TST-01; accessible Docker runner and prebuilt image
- TST-03: TST-02; approved model fixture and available CPU/GPU validation hosts

## [Preserve router configuration and document recovery](plans/persistent-state.md)

- DAT-01: No feature prerequisite.
- DAT-02: Accessible Docker host with disposable test volumes

## [Verify platform support and a genuine CPU path](plans/platform-contract.md)

- PLT-01: No feature prerequisite.
- PLT-02: REP-01; provisioned builder and approved CPU model fixture

## [Make onboarding and release documentation consistent](plans/docs-onboarding.md)

- DOC-01: No feature prerequisite.

## [Make environment validation and instance creation dependable](plans/environment-validation.md)

- ENV-01: No feature prerequisite.
- ENV-02: ENV-01

## [Unify internal ports and generated client defaults](plans/port-and-agent-contracts.md)

- PRT-01: ENV-01
- PRT-02: CFG-01

## [Reduce measured build and idle resource costs](plans/build-and-runtime-efficiency.md)

- EFF-01: Accessible benchmark Docker host and fixed image input revisions
- EFF-02: EFF-01, REP-01; provisioned image builder
- EFF-03: TST-02
- EFF-04: EFF-01, PRT-02; accessible benchmark Docker host

