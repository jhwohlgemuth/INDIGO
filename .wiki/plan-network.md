# Dependency network

Only phase prerequisites are blockers. Integration-lock conflicts require serialization, not prerequisite edges. External host, model, registry and fixture availability is required where named; waiting does not consume active budgets.

## [Make OpenViking host access explicit and secure](openviking-access.md)

- NET-02: Accessible Docker host and disposable OpenViking 0.4.17 config with root and tenant user keys

## [Render model and workspace paths safely](safe-config-rendering.md)

- CFG-02: No feature prerequisite; provisioned image or Docker host for live MCP validation

## [Pin and verify build inputs](reproducible-builds.md)

- REP-01: No feature prerequisite; provisioned image builder and access to the selected upstream revision
- REP-02: REP-01; access to upstream registries and a provisioned image builder
- REP-03: No feature prerequisite.
- REP-04: No feature prerequisite; access to Homebrew sources and a provisioned image builder

## [Test service behavior before releasing images](runtime-ci.md)

- TST-01: No feature prerequisite.
- TST-02: TST-01; GitHub Actions Docker runner and image built by the workflow
- TST-03: TST-02; approved small model fixture and available CPU validation host

## [Preserve router configuration and document recovery](persistent-state.md)

- DAT-01: No feature prerequisite; accessible Docker host with disposable container and named volume
- DAT-02: DAT-01; accessible Docker host with disposable test volumes

## [Verify platform support, CPU inference, and Apple Silicon MLX](platform-contract.md)

- PLT-02: REP-01; provisioned builder and approved CPU model fixture
- PLT-03: PLT-04, PLT-05; Apple Silicon Mac, working Docker daemon and approved complete MLX-format model
- PLT-04: Apple Silicon Mac and approved tool-capable MLX checkpoint
- PLT-05: Notebook image build/release access and ARM64 Docker validation host

## [Add optional Apple Silicon Uzu inference support](uzu-support.md)

- UZU-01: PLT-03; Apple Silicon Mac, usable Uzu-format checkpoint and upstream source/toolchain access
- UZU-02: UZU-01 and its recorded immutable source/toolchain/checkpoint contract
- UZU-03: UZU-02
- UZU-04: UZU-03
- UZU-05: UZU-04; qualified Mac/Docker host and approved checkpoint

## [Make onboarding and release documentation consistent](docs-onboarding.md)

- DOC-01: No feature prerequisite.

## [Make environment validation and instance creation dependable](environment-validation.md)

- ENV-01: No feature prerequisite.
- ENV-02: ENV-01

## [Unify internal ports and generated client defaults](port-and-agent-contracts.md)

- PRT-01: ENV-01
- PRT-02: No feature prerequisite

## [Reduce measured build and idle resource costs](build-and-runtime-efficiency.md)

- EFF-01: Accessible benchmark Docker host and fixed image input revisions
- EFF-02: EFF-01, REP-01; provisioned image builder
- EFF-03: TST-02
- EFF-04: EFF-01, PRT-02; accessible benchmark Docker host

