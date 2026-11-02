# Dependency network

Only phase prerequisites are blockers. Integration-lock conflicts require serialization, not prerequisite edges. External host, model, registry and fixture availability is required where named; waiting does not consume active budgets.

## [Make OpenViking host access explicit and secure](openviking-access.md)

- NET-02: Accessible Docker host and disposable OpenViking 0.4.17 config with root and tenant user keys

## [Test service behavior before releasing images](runtime-ci.md)

- TST-03: Approved small model fixture and available CPU validation host

## [Verify platform support, CPU inference, and Apple Silicon MLX](platform-contract.md)

- PLT-02: Provisioned builder and approved CPU model fixture

## [Add optional Apple Silicon Uzu inference support](uzu-support.md)

- UZU-01: Usable Uzu-format checkpoint and upstream source/toolchain access; accepted MLX baseline is recorded in `docs/platform-support.md`
- UZU-02: UZU-01 and its recorded immutable source/toolchain/checkpoint contract
- UZU-03: UZU-02
- UZU-04: UZU-03
- UZU-05: UZU-04; qualified Mac/Docker host and approved checkpoint

## [Reduce measured build and idle resource costs](build-and-runtime-efficiency.md)

- EFF-03: Authenticated permission to create or update a test PR and hosted runs that reach the image build

