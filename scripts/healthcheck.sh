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
status=0

check() {
    local name="$1"
    local url="$2"
    shift 2
    if curl --fail --silent --show-error --max-time 5 "$@" "${url}" > /dev/null; then
        echo "OK: ${name} (${url})"
    else
        echo "FAIL: ${name} (${url})" >&2
        status=1
    fi
}

check "code-server" "https://${host}:${code_server_port}" --insecure
check "verdaccio" "https://${host}:${verdaccio_port}" --insecure
check "jupyter" "https://${host}:${jupyter_port}" --insecure
check "marimo" "http://${host}:${marimo_port}"
check "inference-router" "http://${host}:${inference_port}${inference_path}"
check "filesystem-mcp" "http://${host}:${mcp_filesystem_port}/healthz"
check "rust-analyzer-mcp" "http://${host}:${mcp_rust_analyzer_port}/healthz"
if [[ -s "${openviking_config}" ]]; then
    check "openviking" "http://${host}:${openviking_port}${openviking_health_path}"
else
    echo "WAIT: openviking (${openviking_config} is not configured)"
fi
check "pinokio" "http://${host}:${pinokio_port}/"
check "pinokio-proxy" "http://${host}:${pinokio_proxy_port}/" --header "Host: ${pinokio_domain}"

exit "${status}"
