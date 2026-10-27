#!/usr/bin/env bash
# shellcheck shell=bash
#
# Validate that an Indigo environment file carries every value required by
# compose.yaml and the Makefile. Those values have no fallbacks, so a missing or
# malformed key must fail loudly here instead of silently rendering an empty
# string into an image reference or a published port.
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

if [[ ! -f "${env_file}" ]]; then
    echo "error: environment file not found: ${env_file}" >&2
    exit 1
fi

status=0

value_of() {
    awk -F= -v key="$1" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "${env_file}"
}

count_of() {
    awk -F= -v key="$1" '$1 == key { count++ } END { print count + 0 }' "${env_file}"
}

for key in "${required[@]}"; do
    value="$(value_of "${key}")"
    if [[ -z "${value}" ]]; then
        echo "error: ${key} is missing or empty in ${env_file}" >&2
        status=1
        continue
    fi
    occurrences="$(count_of "${key}")"
    if [[ "${occurrences}" -gt 1 ]]; then
        echo "error: ${key} is defined ${occurrences} times in ${env_file}" >&2
        status=1
    fi
done

notebook_digest="$(value_of NOTEBOOK_DIGEST)"
if [[ ! "${notebook_digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "error: NOTEBOOK_DIGEST must be a sha256 digest in ${env_file}" >&2
    status=1
fi

mlx_port_occurrences="$(count_of INDIGO_MLX_PORT)"
if [[ "${mlx_port_occurrences}" -gt 1 ]]; then
    echo "error: INDIGO_MLX_PORT is defined more than once in ${env_file}" >&2
    status=1
fi

declare_list=()
for key in "${required[@]}"; do
    if [[ "${key}" == *_PUBLISHED_PORT ]]; then
        declare_list+=("${key}")
    fi
done
declare_list+=(INDIGO_MLX_PORT)

ports=()
for key in "${declare_list[@]}"; do
    value="$(value_of "${key}")"
    [[ -n "${value}" ]] || continue
    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
        echo "error: ${key} is not a number in ${env_file}: ${value}" >&2
        status=1
        continue
    fi
    if ((value < 1 || value > 65535)); then
        echo "error: ${key} is out of range in ${env_file}: ${value}" >&2
        status=1
        continue
    fi
    ports+=("${value}")
done

for index in "${!ports[@]}"; do
    for other in "${!ports[@]}"; do
        if [[ "${other}" -gt "${index}" && "${ports[${index}]}" -eq "${ports[${other}]}" ]]; then
            echo "error: port ${ports[${index}]} is published by more than one service in ${env_file}" >&2
            status=1
        fi
    done
done

if [[ ${status} -ne 0 ]]; then
    echo "error: ${env_file} is not a valid Indigo environment" >&2
    exit 1
fi

echo "OK: ${env_file} defines all ${#required[@]} required values"
