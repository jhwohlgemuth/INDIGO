#!/usr/bin/env bash
set -euo pipefail

host="${HEALTHCHECK_HOST:-localhost}"
code_server_port="${CODE_SERVER_PORT:-1337}"
verdaccio_port="${VERDACCIO_PORT:-4873}"
jupyter_port="${JUPYTER_PORT:-13337}"
marimo_port="${MARIMO_PORT:-13338}"
inference_port="${LLAMA_ARG_PORT:-10732}"
inference_path="${INDIGO_HEALTH_PATH:-/health}"
mcp_filesystem_port="${MCP_FILESYSTEM_PORT:-11002}"
mcp_rust_analyzer_port="${MCP_RUST_ANALYZER_PORT:-11003}"
openviking_config="${OPENVIKING_CONFIG_FILE:-${HOME}/.openviking/ov.conf}"
openviking_port="${OPENVIKING_SERVER_PORT:-1933}"
openviking_health_path="${OPENVIKING_HEALTH_PATH:-/health}"
pinokio_port="${PINOKIO_PORT:-42000}"
pinokio_proxy_port="${PINOKIO_PROXY_PORT:-8080}"
pinokio_domain="${PINOKIO_DOMAIN:-pinokio.localhost}"
result_dir="$(mktemp -d "${TMPDIR:-/tmp}/indigo-health.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
descriptions=()
pids=()
status=0

queue_check() {
    local name="$1"
    local url="$2"
    local index="${#descriptions[@]}"
    shift 2
    descriptions+=("${name} (${url})")
    (
        if curl --fail --silent --show-error --max-time 5 "$@" "${url}" > /dev/null 2>&1; then
            printf 'OK\n' > "${result_dir}/${index}"
        else
            printf 'FAIL\n' > "${result_dir}/${index}"
        fi
    ) &
    pids+=("$!")
}

queue_wait() {
    local index="${#descriptions[@]}"
    descriptions+=("$1")
    printf 'WAIT\n' > "${result_dir}/${index}"
}

queue_check "code-server" "https://${host}:${code_server_port}" --insecure
queue_check "verdaccio" "https://${host}:${verdaccio_port}" --insecure
queue_check "jupyter" "https://${host}:${jupyter_port}" --insecure
queue_check "marimo" "http://${host}:${marimo_port}"
if [[ "${INDIGO_ENABLE_INFERENCE:-1}" =~ ^(1|true|yes|on)$ ]]; then
    queue_check "inference-router" "http://${host}:${inference_port}${inference_path}"
fi
if [[ "${INDIGO_ENABLE_FILESYSTEM:-0}" =~ ^(1|true|yes|on)$ ]]; then
    queue_check "filesystem-mcp" "http://${host}:${mcp_filesystem_port}/healthz"
fi
if [[ "${INDIGO_ENABLE_RUST_ANALYZER:-0}" =~ ^(1|true|yes|on)$ ]]; then
    queue_check "rust-analyzer-mcp" "http://${host}:${mcp_rust_analyzer_port}/healthz"
fi
if [[ "${INDIGO_ENABLE_OPENVIKING:-0}" =~ ^(1|true|yes|on)$ ]]; then
    if [[ -s "${openviking_config}" ]]; then
        queue_check "openviking" "http://${host}:${openviking_port}${openviking_health_path}"
    else
        queue_wait "openviking (${openviking_config} is not configured)"
    fi
fi
if [[ "${INDIGO_ENABLE_PINOKIO:-0}" =~ ^(1|true|yes|on)$ ]]; then
    queue_check "pinokio" "http://${host}:${pinokio_port}/"
    queue_check "pinokio-proxy" "http://${host}:${pinokio_proxy_port}/" --header "Host: ${pinokio_domain}"
fi

for pid in "${pids[@]}"; do
    wait "${pid}"
done

for index in "${!descriptions[@]}"; do
    result="$(< "${result_dir}/${index}")"
    case "${result}" in
        OK | WAIT) printf '%s: %s\n' "${result}" "${descriptions[${index}]}" ;;
        *)
            printf 'FAIL: %s\n' "${descriptions[${index}]}" >&2
            status=1
            ;;
    esac
done

exit "${status}"
