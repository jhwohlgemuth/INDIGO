# Release input updates

```pikchr
scale = 0.76
Release: box "Reviewed" "release" wid 1.0in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0
arrow right 0.35in thick color 0x5B4BC4
Resolve: box "Resolve tag +" "digest" wid 1.05in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0
arrow right 0.35in thick color 0x5B4BC4
Pair: box "Update version" "+ digest" wid 1.1in ht 0.52in rad 0.08in fill 0xE0E7FF thickness 0
arrow right 0.35in thick color 0x5B4BC4
Checks: box "Checks +" "image smoke" wid 1.05in ht 0.52in rad 0.08in fill 0xF3E8FF thickness 0
arrow right 0.35in thick color 0x5B4BC4
Evidence: box "Record platform" "evidence" wid 1.15in ht 0.52in rad 0.08in fill 0xF5F3FF thickness 0
```

The Container workflow uses `actions/checkout` v4.4.0 at commit
`11d5960a326750d5838078e36cf38b85af677262`. The tag was resolved with
`git ls-remote https://github.com/actions/checkout.git refs/tags/v4.4.0`.

The Linux CI formatter is shfmt v3.11.0. Its `linux_amd64` release asset has
SHA-256 `1904ec6bac715c1d05cd7f6612eec8f67a625c3749cb327e5bfb4127d09035ff`.
The workflow checks the digest before installing the binary.
The [2026-10-27 Container run](https://github.com/jhwohlgemuth/INDIGO/actions/runs/40573556693)
passed the shfmt installation, shell checks, and lint steps before the hosted
runner lost communication during image build.

Linux CI runs Hadolint v2.15.1 from the `linux/amd64` container image at
`ghcr.io/hadolint/hadolint:v2.15.1-debian@sha256:aacf4eda44e40057051f5c5b02546e3ada7e8b84d4bbf9312c89524a7e9a0b51`.
Resolve its architecture-specific digest from the upstream package page when
updating the version.

To update these inputs, select a reviewed upstream release, resolve the action
tag to a full commit or download the formatter asset from the release URL,
record its SHA-256, update the workflow, and run `make check` and `make lint`.
For the formatter, verify that changing one byte makes the digest check fail.
Review the Linux and Windows workflow results before merging the update.

INDIGO uses `ghcr.io/jhwohlgemuth/notebook:1.0.5` as its direct base. On
2026-10-27, its published multi-platform index resolved to
`sha256:c3256bd1d46ffd71f6c7b95cc0da7cca1c2ddc417070f3a7622bd557838be7dd`.
The index contains Linux amd64 and arm64 manifests. `NOTEBOOK_VERSION` and
`NOTEBOOK_DIGEST` in `.env` select this pair for Compose and Make builds; the
Dockerfile repeats it as the default for direct builds. Update both values
together after inspecting the published manifest and testing the resulting
INDIGO image on the intended architectures. Gold remains a separate image and
Terminal is inherited through Notebook, so INDIGO does not pin them directly.

The inherited Notebook code-server bundle is replaced during the INDIGO build
with `ghcr.io/coder/code-server:4.143.1` at multi-platform index digest
`sha256:377b66bec5645510ed52549bb00e648c273edc604d230a3f90fd2b2433afcb97`.
The reviewed index resolves Linux amd64 to
`sha256:bc1a44f83c207dd9607cad8f5a13843918131361e899b4ebae9b786f5adbb76f`
and Linux arm64 to
`sha256:01ea4293f12df785c7e6d760c82ed80a594f093ec01b38ec707e22e64b691b83`.
The complete `/usr/lib/code-server` tree is copied so its bundled Node binary
and native modules resolve for the target architecture together. When updating
this input, inspect the index for both Linux amd64 and arm64 manifests, update
`CODE_SERVER_VERSION` and `CODE_SERVER_DIGEST` together, run
`tests/build-inputs.sh`, and verify `code-server --version`, ELF machine IDs,
and `scripts/runtime-smoke.sh` on ARM64.

All direct OCI base references are tag-plus-digest pinned. The remaining Docker
Hub inputs were resolved on 2026-11-01 with
`docker buildx imagetools inspect` against the official-library names:

| Build stage | Reviewed reference | Multi-platform index | Linux amd64 manifest | Linux arm64 manifest |
| --- | --- | --- | --- | --- |
| Pinokio source and build | `node:20` | `sha256:8f693eaa7e0a8e71560c9a82b55fd54c2ae920a2ba5d2cde28bac7d1c01c9ba5` | `sha256:cacf10e99285cbbc891452e31249c1b5ec3ba225f40028fae946b75aeaf1b66a` | `sha256:f5b23dfa20dc91f65416e7d8dbee9f7a728a5677a53f711a1047f0eaac77d8f0` |
| Pinokio Caddy | `caddy:2.9.1` | `sha256:748016f285ed8c43a9ce6e3aed6d92d3009d90ca41157950880f40beaf3ff62b` | `sha256:cf1bd22f2415bc99b785ece1df2c49d32985ac4ac42d84df335be17350593693` | `sha256:dc5640f3339bba2a36cb20392dd32d432bd88d14275cdf1f3637f3107caf7ecc` |
| MCP Node runtime | `node:24-bookworm-slim` | `sha256:c86ecead9e55a5210ac1727de38a4ca840bf03dcaf34dc9749addbf383b1920c` | `sha256:a43f7fc3e52e87d12a905f46eea0275def84ca8f2981a5b53fed44d7fb398ee0` | `sha256:e80dee4ed3709cf1f8004e34ecfb90df71b7eac8ba0d7d6222ba238a823d1eea` |
| Rust toolchain | `rust:1.90-bookworm` | `sha256:3914072ca0c3b8aad871db9169a651ccfce30cf58303e5d6f2db16d1d8a7e58f` | `sha256:3f6e6f8d8725a65a2db964bb828850f888d430c68784d661f753144e5d787207` | `sha256:4c632e493dfa97f0fe014c3910d1690c149bba85ed8678d47d3563ec6f258ead` |

When updating an OCI base, inspect the candidate tag's index in the registry,
confirm that it still contains the intended Linux amd64 and arm64 manifests,
and review the upstream release and base-distribution change. Update the
version and digest arguments together; never refresh a digest without recording
which tag and platforms were reviewed. Run `make check`, `make lint`, a CPU
image build, and `make image-smoke` on the resulting image. Exercise an ARM64
build whenever the changed index or copied artifacts are architecture-sensitive.

These pins make the selected OCI manifests immutable, not the whole build
bit-for-bit reproducible. `apt-get` still resolves the current package indexes
without a Debian snapshot or package-version lock. The OpenViking pip command
pins only its top-level version, so its transitive requirements can change.
Pinokio's `npm ci` uses the source commit's lockfile, but the global MCP npm
installs pin only top-level versions and resolve transitive packages at build
time. Homebrew bottles and formula resolution remain a separate guarded update
phase. Review these moving inputs in every dependency update even when the OCI
base digests are unchanged.
