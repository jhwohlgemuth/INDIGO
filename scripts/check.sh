#!/usr/bin/env bash
# shellcheck shell=bash
#
# Validate the deliberately small environment-file grammar shared by Make,
# Compose, and scripts/new.sh. Never source or evaluate the file: an invalid
# assignment must fail here instead of acquiring different meanings in each
# consumer.
#
# Usage: scripts/check.sh [env-file]
set -euo pipefail

env_file="${1:-${ENV_FILE:-.env}}"

required=(
    VERSION
    REGISTRY
    REGISTRY_PROJECT
    IMAGE
    NOTEBOOK_VERSION
    NOTEBOOK_DIGEST
    INDIGO_HOSTNAME
    PINOKIO_DOMAIN
    INDIGO_SHM_SIZE
    INDIGO_STOP_GRACE_PERIOD
    INDIGO_PUBLISH_HOST
    INFERENCE_PUBLISHED_PORT
    CODE_SERVER_PUBLISHED_PORT
    VERDACCIO_PUBLISHED_PORT
    JUPYTER_PUBLISHED_PORT
    MARIMO_PUBLISHED_PORT
    OPENVIKING_PUBLISHED_PORT
    PINOKIO_PUBLISHED_PORT
    PINOKIO_PROXY_PUBLISHED_PORT
    MCP_FILESYSTEM_PUBLISHED_PORT
    MCP_RUST_ANALYZER_PUBLISHED_PORT
)

optional=(
    COMPOSE_PROJECT_NAME
    INDIGO_DEFAULT_MODEL
    INDIGO_DEFAULT_MODEL_PATH
    INDIGO_ENABLE_FILESYSTEM
    INDIGO_ENABLE_INFERENCE
    INDIGO_ENABLE_OPENVIKING
    INDIGO_ENABLE_PINOKIO
    INDIGO_ENABLE_RUST_ANALYZER
    INDIGO_LLAMA_SWAP_CONFIG_PATH
    INDIGO_MLX_PORT
    INDIGO_MLX_SWAP_CONFIG_PATH
    INDIGO_MODELS_PATH
    INDIGO_SEED_AGENT_CONFIG
    INDIGO_WORKSPACE_PATH
    LLAMA_ARG_BATCH
    LLAMA_ARG_CTX_SIZE
    LLAMA_ARG_N_PARALLEL
    LLAMA_ARG_UBATCH
    OPENVIKING_CONF_CONTENT
    OPENVIKING_WITH_BOT
    RUST_ANALYZER_WORKSPACE
)
allowed=("${required[@]}" "${optional[@]}")

if [[ ! -f "${env_file}" ]]; then
    echo "error: environment file not found: ${env_file}" >&2
    exit 1
fi

status=0
keys=()
values=()
key_lines=()
line_number=0

report() {
    echo "error: $*" >&2
    status=1
}

index_of() {
    local requested="$1"
    local index
    for index in "${!keys[@]}"; do
        if [[ "${keys[${index}]}" == "${requested}" ]]; then
            printf '%s\n' "${index}"
            return 0
        fi
    done
    printf '%s\n' -1
}

value_of() {
    local index
    index="$(index_of "$1")"
    if [[ "${index}" -ge 0 ]]; then
        printf '%s\n' "${values[${index}]}"
    fi
}

while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
    line_number=$((line_number + 1))
    line="${raw_line%$'\r'}"

    if [[ -z "${line}" || "${line}" == \#* ]]; then
        continue
    fi

    if [[ ! "${line}" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        report "line ${line_number} in ${env_file} must be KEY=VALUE with no leading whitespace or export prefix"
        continue
    fi

    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    allowed_key_found=0
    for allowed_key in "${allowed[@]}"; do
        if [[ "${allowed_key}" == "${key}" ]]; then
            allowed_key_found=1
            break
        fi
    done
    if [[ ${allowed_key_found} -ne 1 ]]; then
        report "unsupported key ${key} on line ${line_number} in ${env_file}"
        continue
    fi
    if [[ ! "${value}" =~ ^[A-Za-z0-9._/:@,+-]*$ ]]; then
        report "${key} on line ${line_number} in ${env_file} contains unsupported quoting, whitespace, or shell syntax"
        continue
    fi

    previous="$(index_of "${key}")"
    if [[ "${previous}" -ge 0 ]]; then
        report "${key} is defined more than once in ${env_file} (lines ${key_lines[${previous}]} and ${line_number})"
        continue
    fi

    keys+=("${key}")
    values+=("${value}")
    key_lines+=("${line_number}")
done < "${env_file}"

for key in "${required[@]}"; do
    value="$(value_of "${key}")"
    if [[ -z "${value}" ]]; then
        report "${key} is missing or empty in ${env_file}"
    fi
done

validate_pattern() {
    local key="$1"
    local pattern="$2"
    local expectation="$3"
    local value
    value="$(value_of "${key}")"
    [[ -n "${value}" ]] || return 0
    if [[ ! "${value}" =~ ${pattern} ]]; then
        report "${key} must be ${expectation} in ${env_file}: ${value}"
    fi
}

image_component='^[a-z0-9]+([._-][a-z0-9]+)*$'
image_namespace='^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*$'
tag_value='^[A-Za-z0-9_][A-Za-z0-9._-]*$'
host_value='^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'

validate_pattern VERSION "${tag_value}" "an OCI tag-compatible value"
validate_pattern NOTEBOOK_VERSION "${tag_value}" "an OCI tag-compatible value"
validate_pattern REGISTRY '^([A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?)(:[0-9]+)?$' "a registry hostname with an optional decimal port"
validate_pattern REGISTRY_PROJECT "${image_namespace}" "a lowercase OCI namespace"
validate_pattern IMAGE "${image_component}" "a lowercase OCI image name"
validate_pattern NOTEBOOK_DIGEST '^sha256:[0-9a-f]{64}$' "a lowercase sha256 digest"
validate_pattern INDIGO_HOSTNAME "${host_value}" "a hostname without a scheme or port"
validate_pattern PINOKIO_DOMAIN "${host_value}" "a hostname without a scheme or port"
validate_pattern INDIGO_PUBLISH_HOST "${host_value}" "a hostname or IP address without a scheme or port"
validate_pattern INDIGO_SHM_SIZE '^[1-9][0-9]*([kKmMgGtT][bB]?)$' "a positive size such as 2gb"
validate_pattern INDIGO_STOP_GRACE_PERIOD '^[1-9][0-9]*(ns|us|ms|s|m|h)$' "a positive duration such as 1m"

port_keys=()
for key in "${required[@]}"; do
    if [[ "${key}" == *_PUBLISHED_PORT ]]; then
        port_keys+=("${key}")
    fi
done
port_keys+=(INDIGO_MLX_PORT)

port_values=()
port_names=()
for key in "${port_keys[@]}"; do
    value="$(value_of "${key}")"
    [[ -n "${value}" ]] || continue
    if [[ ! "${value}" =~ ^[1-9][0-9]*$ ]]; then
        report "${key} must be a canonical decimal port with no leading zeros in ${env_file}: ${value}"
        continue
    fi

    decimal="${value}"
    if [[ "${#decimal}" -gt 5 ]] || ((decimal > 65535)); then
        report "${key} is out of range in ${env_file}: ${value}"
        continue
    fi

    for index in "${!port_values[@]}"; do
        if [[ "${port_values[${index}]}" -eq "${decimal}" ]]; then
            report "port ${decimal} is assigned to both ${port_names[${index}]} and ${key} in ${env_file}"
        fi
    done
    port_values+=("${decimal}")
    port_names+=("${key}")
done

if [[ ${status} -ne 0 ]]; then
    echo "error: ${env_file} is not a valid Indigo environment" >&2
    exit 1
fi

echo "OK: ${env_file} defines all ${#required[@]} required values"
