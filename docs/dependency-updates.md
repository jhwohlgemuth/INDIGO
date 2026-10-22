# Release input updates

The Container workflow uses `actions/checkout` v4.4.0 at commit
`11d5960a326750d5838078e36cf38b85af677262`. The tag was resolved with
`git ls-remote https://github.com/actions/checkout.git refs/tags/v4.4.0`.

The Linux CI formatter is shfmt v3.11.0. Its `linux_amd64` release asset has
SHA-256 `1904ec6bac715c1d05cd7f6612eec8f67a625c3749cb327e5bfb4127d09035ff`.
The workflow checks the digest before installing the binary.

Linux CI runs Hadolint v2.15.1 from the `linux/amd64` container image at
`ghcr.io/hadolint/hadolint:v2.15.1-debian@sha256:aacf4eda44e40057051f5c5b02546e3ada7e8b84d4bbf9312c89524a7e9a0b51`.
Resolve its architecture-specific digest from the upstream package page when
updating the version.

To update these inputs, select a reviewed upstream release, resolve the action
tag to a full commit or download the formatter asset from the release URL,
record its SHA-256, update the workflow, and run `make check` and `make lint`.
For the formatter, verify that changing one byte makes the digest check fail.
Review the Linux and Windows workflow results before merging the update.

The image's inference source, OCI base images, and Homebrew versions have
separate remaining phases in the planning portfolio. This record does not claim
bit-for-bit reproducible images while those inputs and transitive packages can
still change.
