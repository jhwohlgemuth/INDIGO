#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${repository_root}/scripts/check.sh"
base="${repository_root}/.env"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-env-validation.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT

replace_value() {
    local source="$1"
    local target="$2"
    local key="$3"
    local value="$4"
    awk -v key="${key}" -v value="${value}" '
        index($0, key "=") == 1 { $0 = key "=" value }
        { print }
    ' "${source}" > "${target}"
}

remove_key() {
    local source="$1"
    local target="$2"
    local key="$3"
    awk -v key="${key}" 'index($0, key "=") != 1 { print }' \
        "${source}" > "${target}"
}

expect_pass() {
    local file="$1"
    local output
    output="$("${checker}" "${file}")"
    [[ "${output}" == OK:* ]]
}

expect_compose() {
    local file="$1"
    docker compose --env-file "${file}" \
        -f "${repository_root}/compose.yaml" config --quiet
}

expect_fail() {
    local file="$1"
    local expected="$2"
    if "${checker}" "${file}" > "${fixture}/out" 2> "${fixture}/err"; then
        echo "expected environment validation to fail: ${file}" >&2
        exit 1
    fi
    grep -Fq "${expected}" "${fixture}/err"
    grep -Fq "is not a valid Indigo environment" "${fixture}/err"
}

expect_pass "${base}"
expect_compose "${base}"

crlf="${fixture}/crlf.env"
while IFS= read -r line || [[ -n "${line}" ]]; do
    printf '%s\r\n' "${line}"
done < "${base}" > "${crlf}"
expect_pass "${crlf}"
expect_compose "${crlf}"

decimal_port="${fixture}/decimal-port.env"
replace_value "${base}" "${decimal_port}" INFERENCE_PUBLISHED_PORT 08
expect_fail "${decimal_port}" "INFERENCE_PUBLISHED_PORT must be a canonical decimal port with no leading zeros"

optional="${fixture}/optional.env"
cp "${base}" "${optional}"
printf '%s\n' 'LLAMA_ARG_CTX_SIZE=4096' >> "${optional}"
expect_pass "${optional}"
expect_compose "${optional}"

duplicate="${fixture}/duplicate.env"
cp "${base}" "${duplicate}"
printf '%s\n' 'VERSION=9.9.9' >> "${duplicate}"
expect_fail "${duplicate}" "VERSION is defined more than once"

duplicate_optional="${fixture}/duplicate-optional.env"
cp "${optional}" "${duplicate_optional}"
printf '%s\n' 'LLAMA_ARG_CTX_SIZE=8192' >> "${duplicate_optional}"
expect_fail "${duplicate_optional}" "LLAMA_ARG_CTX_SIZE is defined more than once"

quoted="${fixture}/quoted.env"
replace_value "${base}" "${quoted}" VERSION '"0.1.4"'
expect_fail "${quoted}" "VERSION on line"
grep -Fq "unsupported quoting, whitespace, or shell syntax" "${fixture}/err"

whitespace="${fixture}/whitespace.env"
replace_value "${base}" "${whitespace}" VERSION ' 0.1.4'
expect_fail "${whitespace}" "unsupported quoting, whitespace, or shell syntax"

leading_whitespace="${fixture}/leading-whitespace.env"
awk 'index($0, "VERSION=") == 1 { $0 = " " $0 } { print }' \
    "${base}" > "${leading_whitespace}"
expect_fail "${leading_whitespace}" "must be KEY=VALUE with no leading whitespace or export prefix"

export_prefix="${fixture}/export.env"
awk 'index($0, "VERSION=") == 1 { $0 = "export " $0 } { print }' \
    "${base}" > "${export_prefix}"
expect_fail "${export_prefix}" "must be KEY=VALUE with no leading whitespace or export prefix"

missing="${fixture}/missing.env"
remove_key "${base}" "${missing}" IMAGE
expect_fail "${missing}" "IMAGE is missing or empty"

empty="${fixture}/empty.env"
replace_value "${base}" "${empty}" IMAGE ''
expect_fail "${empty}" "IMAGE is missing or empty"

invalid_image="${fixture}/invalid-image.env"
replace_value "${base}" "${invalid_image}" IMAGE 'Bad/Image'
expect_fail "${invalid_image}" "IMAGE must be a lowercase OCI image name"

invalid_registry="${fixture}/invalid-registry.env"
replace_value "${base}" "${invalid_registry}" REGISTRY 'https://ghcr.io'
expect_fail "${invalid_registry}" "REGISTRY must be a registry hostname"

invalid_host="${fixture}/invalid-host.env"
replace_value "${base}" "${invalid_host}" INDIGO_PUBLISH_HOST 'http://127.0.0.1'
expect_fail "${invalid_host}" "INDIGO_PUBLISH_HOST must be a hostname or IP address"

not_decimal="${fixture}/not-decimal.env"
replace_value "${base}" "${not_decimal}" INFERENCE_PUBLISHED_PORT '12x'
expect_fail "${not_decimal}" "INFERENCE_PUBLISHED_PORT must be a canonical decimal port"

zero_port="${fixture}/zero-port.env"
replace_value "${base}" "${zero_port}" INFERENCE_PUBLISHED_PORT 000
expect_fail "${zero_port}" "INFERENCE_PUBLISHED_PORT must be a canonical decimal port"

overflow="${fixture}/overflow.env"
replace_value "${base}" "${overflow}" INFERENCE_PUBLISHED_PORT 999999999999999999999
expect_fail "${overflow}" "INFERENCE_PUBLISHED_PORT is out of range"

unsupported="${fixture}/unsupported.env"
cp "${base}" "${unsupported}"
printf '%s\n' 'INDIGO_UNKNOWN_SETTING=value' >> "${unsupported}"
expect_fail "${unsupported}" "unsupported key INDIGO_UNKNOWN_SETTING"

echo 'environment validation contract passed'
