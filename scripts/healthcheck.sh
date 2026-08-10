#!/usr/bin/env bash
set -euo pipefail

host="${HEALTHCHECK_HOST:-localhost}"
code_server_port="${CODE_SERVER_PORT:-1337}"
verdaccio_port="${VERDACCIO_PORT:-4873}"
jupyter_port="${JUPYTER_PORT:-13337}"
marimo_port="${MARIMO_PORT:-13338}"
inference_port="${LLAMA_ARG_PORT:-10732}"
inference_path="${GOLDSMITH_HEALTH_PATH:-/health}"
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

exit "${status}"
