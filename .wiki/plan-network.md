# Dependency network

Only phase prerequisites are blockers. Integration-lock conflicts require serialization, not prerequisite edges. External host, model, registry and fixture availability is required where named; waiting does not consume active budgets.

## [Make OpenViking host access explicit and secure](openviking-access.md)

- NET-02: Accessible Docker host and disposable OpenViking 0.4.17 config with root and tenant user keys

## [Render model and workspace paths safely](safe-config-rendering.md)

- CFG-02: No feature prerequisite; provisioned image or Docker host for live MCP validation

## [Pin and verify build inputs](reproducible-builds.md)

- REP-04: No feature prerequisite; access to Homebrew sources and a provisioned image builder

## [Test service behavior before releasing images](runtime-ci.md)

- TST-03: Approved small model fixture and available CPU validation host

## [Preserve router configuration and document recovery](persistent-state.md)

- DAT-01: No feature prerequisite; accessible Docker host with disposable container and named volume
- DAT-02: DAT-01; accessible Docker host with disposable test volumes

## [Verify platform support, CPU inference, and Apple Silicon MLX](platform-contract.md)

- PLT-02: Provisioned builder and approved CPU model fixture

## [Add optional Apple Silicon Uzu inference support](uzu-support.md)

- UZU-01: Usable Uzu-format checkpoint and upstream source/toolchain access; accepted MLX baseline is recorded in `docs/platform-support.md`
- UZU-02: UZU-01 and its recorded immutable source/toolchain/checkpoint contract
- UZU-03: UZU-02
- UZU-04: UZU-03
- UZU-05: UZU-04; qualified Mac/Docker host and approved checkpoint

## [Make environment validation and instance creation dependable](environment-validation.md)

- ENV-02: No feature prerequisite; shared environment grammar is enforced by `scripts/check.sh`

## [Unify internal ports and generated client defaults](port-and-agent-contracts.md)

- PRT-01: No feature prerequisite; validated environment contract is recorded in `docs/environment.md`

## [Reduce measured build and idle resource costs](build-and-runtime-efficiency.md)

- EFF-03: Authenticated permission to create or update a test PR and hosted runs that reach the image build

