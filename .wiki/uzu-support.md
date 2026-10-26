---
type: Plan
title: Add optional Apple Silicon Uzu inference support
description: An Apple Silicon user can opt into a native Uzu server through INDIGO's existing OpenAI-compatible router after the MLX path has passed runtime acceptance.
difficulty: high
impact: medium
package: [indigo]
tags: [uzu, apple-silicon, inference]
status: waiting-on-validation
execution: phased
phase_budget_hours: 5
---

# Add optional Apple Silicon Uzu inference support

## Current evidence

Reviewed 2026-10-25 at commit e867187073fe14336eb13cc71c735be652eb5030. INDIGO's default Linux image serves `llama.cpp` through `llama-swap`; the opt-in Apple Silicon mode runs `mlx-lm` natively and peers it through the same router. `compose.mlx.yaml`, `scripts/mlx-host.sh`, and separate router/OpenCode templates establish a usable pattern, but the [platform evidence](../docs/platform-support.md) still marks Mac build and model-serving validation pending. PLT-03 in [platform-contract](platform-contract.md) is the required acceptance gate. No Uzu code or checkpoint has been installed or benchmarked here.

Upstream [Uzu documentation](https://github.com/trymirai/uzu#server) describes an OpenAI-compatible server with `/v1/chat/completions` and `/v1/models`. Its [server source](https://github.com/trymirai/uzu/blob/main/crates/legacy/cli/src/server/chat_completions.rs) accepts streaming and tool calls, but serializes requests through one session. It uses [its own model format](https://github.com/trymirai/uzu#model-format); Metal and CPU are listed, while Linux/Windows targets are in progress. The current [model catalog](https://trymirai.com/models) reports speed on specific Apple hardware, not an INDIGO comparison. Its moving nightly toolchain and the README/package version mismatch make a tested source commit and toolchain pin necessary before packaging a host runner.

## Boundaries and decisions

- Keep CUDA `llama.cpp` as the Linux default and MLX as the initial Apple Silicon default. Uzu is opt-in and runs on macOS, never inside the Linux container. Retain port 10732 as the client endpoint; the host Uzu server uses a separate instance-offset port, initially 10734.
- Reuse the existing ARM64 CPU INDIGO image and `llama-swap` peer pattern. Give Uzu its own Compose override, router state and OpenCode config volume so switching modes cannot overwrite MLX or standard state. Present a stable `indigo/uzu/default_model` client alias; validate that routing works with Uzu's actual loaded model ID.
- Require an explicit `UZU_MODEL` value, accepting a local Uzu-format directory or an explicitly chosen upstream model ID. No silent conversion of GGUF/MLX assets and no change to ACORN's existing model acquisition contract. A model-ID choice may trigger Uzu's documented download into Uzu-owned host state.
- Build the upstream CLI from the exact commit and Rust toolchain qualified in UZU-01 using its lockfile. Do not track a floating `main` branch or bundle Uzu into the default image. Keep host processes under a per-instance launchd label and use `/v1/models` for readiness because the documented server has no `/health` endpoint.
- Do not claim performance improvement from upstream figures. Record end-to-end agent latency, output quality, memory and concurrency behavior against a verified MLX baseline; a different quantization or checkpoint must be labeled as such. Uzu support is accepted on functional compatibility, not a preset speed threshold.

## Dependencies

PLT-03 must have passed and its result must be recorded in `docs/platform-support.md` before any Uzu phase starts. UZU-01 also needs an Apple Silicon Mac, a usable Uzu-format checkpoint and source/toolchain access; downloads and machine availability are external waiting. Later phases depend on the qualified commit and API contract from UZU-01. Shared Makefile, image-template and runtime-docs locks serialize overlapping portfolio work but are not feature prerequisites.

## Acceptance criteria

- `make up-uzu` starts one pinned native Uzu server and the ARM64 INDIGO router without altering MLX or standard config; `make down-uzu` stops only that instance's processes and container.
- `/v1/models`, streamed chat, and a tool-call/tool-result round trip work through `http://127.0.0.1:10732/v1`; OpenCode can select `indigo/uzu/default_model`. A second instance uses distinct host and router ports and state.
- Source revision, toolchain, model identity/hash, hardware, timing, memory, concurrent-request behavior and failure/cleanup results are recorded. Documentation states the Uzu-format and Apple Silicon limits and the measured comparison with MLX.
- Config rendering, offline host-script fixtures and a real routed Mac acceptance run pass. If upstream cannot meet the functional contract, keep the plan blocked with evidence; do not mark Uzu supported.

## Validation

Use the focused checks in each phase and only test-owned model/process/container state. Never treat router liveness, a CLI build or upstream marketing numbers as model-serving proof. Record failures and split unexpected repairs into new bounded phases. Each phase has at most five active hours; fixture downloads and external host/CI waiting are prerequisites.

# Execution phases

## UZU-01 — Qualify a pinned upstream server and checkpoint

- Status: blocked
- Budget: 5 active hours maximum
- Prerequisites: PLT-03; Apple Silicon Mac, usable Uzu-format checkpoint, and upstream source/toolchain access
- Exact write set: `scripts/uzu-acceptance.sh`, `docs/uzu-evaluation.md`
- Primary integration lock: mac-inference-validation
- Outcome: Identify an immutable Uzu commit, compatible Rust toolchain, checkpoint and actual HTTP behavior for an INDIGO host peer; document any incompatibility before integration begins.
- Focused validation: Build `cli` with its lockfile at the recorded commit; start its server on a disposable host port; exercise `/v1/models`, streamed chat, tool-call/tool-result exchange, explicit model ID handling, server restart and two overlapping requests. Record checkpoint provenance/hash, macOS/SoC/RAM, build command, response shapes, errors and observed queueing. Compare an equivalent MLX task/model family when available, marking format/quantization differences.
- Handoff: Preserve the qualified commit, toolchain, checkpoint, API fixtures and measurements in `docs/uzu-evaluation.md`; remove UZU-01 only if the client-critical contract passes, then release UZU-02. Otherwise retain the phase with a precise failing request and response.

## UZU-02 — Manage a pinned Uzu host service

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: UZU-01 and its recorded commit, toolchain and checkpoint contract
- Exact write set: `scripts/uzu-host.sh`, `tests/uzu-host.sh`, `Makefile`, `.env`
- Primary integration lock: mac-host-runtime
- Outcome: Provide opt-in `make uzu-setup`, `uzu-start`, `uzu-status` and `uzu-stop` commands. Build the qualified CLI into `.indigo/uzu/`, require `UZU_MODEL`, launch it per instance, and reject a running instance whose model, port or binary differs from the requested settings.
- Focused validation: Offline command/launchd fixtures cover Apple Silicon and port checks, missing model, pinned revision/toolchain, repeat start, changed settings, readiness on `/v1/models`, timeout, stop and isolation from the MLX launchd label. On the qualified Mac, start the actual binary and verify that the selected local model or explicit model ID loads.
- Handoff: Record the pinned build inputs and host-service test results; remove UZU-02 once the host server starts and stops independently of INDIGO, then release UZU-03.

## UZU-03 — Route Uzu through the opt-in INDIGO image mode

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: UZU-02
- Exact write set: `config/llama-swap/uzu.yaml`, `config/agents/opencode.uzu.json`, `compose.uzu.yaml`, `Dockerfile`, `rootfs/etc/cont-init.d/20-indigo-agent-config`, `tests/config-seeding.sh`
- Primary integration lock: router-config-seeding
- Outcome: Add `INDIGO_ROUTER_MODE=uzu` with a dedicated peer, stable client alias, ARM64 CPU image selection, and separate router/OpenCode state selected by `INDIGO_UZU_SWAP_CONFIG_PATH`. Preserve existing user-managed files on restart and leave default/MLX paths unchanged.
- Focused validation: Render base plus Uzu Compose; fixture-test first-run config, restart without overwrite, mode-specific volume selection and peer port interpolation. With the Uzu host service running, confirm the router lists `uzu/default_model` and forwards a simple completion to the loaded model.
- Handoff: Record config contract results and the exact mapped model ID; remove UZU-03 when manually started Uzu can serve through INDIGO, then release UZU-04.

## UZU-04 — Wire one-command startup and instance separation

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: UZU-03
- Exact write set: `Makefile`, `scripts/check.sh`, `scripts/new.sh`, `tests/run-platform.sh`, `README.md`, `docs/platform-support.md`
- Primary integration lock: mac-mode-orchestration
- Outcome: Add `make up-uzu`/`down-uzu`, validate `INDIGO_UZU_PORT`, and offset its port and config path for new instances. Explain explicit model selection, host network exposure, state, cleanup and mode switching without changing the default launch commands.
- Focused validation: Shell and Make dry-run fixtures for two instances, duplicate/out-of-range/conflicting Uzu ports, correct start/stop order and failed-start cleanup; render Compose for base and two generated instance files. Run `make check` and `make lint` for the changed surfaces.
- Handoff: Record command and instance-contract results; remove UZU-04 when the opt-in path is reviewable and documented, then release UZU-05 for live acceptance.

## UZU-05 — Verify routed agent behavior and record the comparison

- Status: planned
- Budget: 5 active hours maximum
- Prerequisites: UZU-04; qualified Apple Silicon Mac, approved checkpoint and working Docker daemon
- Exact write set: `scripts/uzu-acceptance.sh`, `docs/uzu-evaluation.md`, `docs/platform-support.md`
- Primary integration lock: mac-inference-validation
- Outcome: Establish real host-to-router-to-OpenCode Uzu evidence and compare it with the already verified MLX path; keep Uzu labeled experimental until this run passes.
- Focused validation: Run `make up-uzu` and check `/v1/models`, streamed chat, tool-call/tool-result round trip, OpenCode selection, a second instance, restart preservation, `make down-uzu` and error cleanup. Reuse the same prompts and comparable model family for MLX and Uzu; report median end-to-end time, first-token time, tokens/s, peak resident memory, tool success and queued two-client behavior with three warm runs each. Record hardware, revisions, model hashes, quantization differences and raw command/results.
- Handoff: Move the durable support matrix and measured comparison into docs, remove UZU-05 and retire this plan once all acceptance criteria pass. If a functional check fails, retain the phase or add a bounded repair phase and keep the user-facing support claim pending.
