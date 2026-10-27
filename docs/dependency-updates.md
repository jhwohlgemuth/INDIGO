# Release input updates

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

The inference source, other OCI base images, and Homebrew versions have
separate remaining phases in the planning portfolio. This record does not claim
bit-for-bit reproducible images while those inputs and transitive packages can
still change.
