#!/usr/bin/env bash
# Boot the built image through /init and verify the default services without a model.
set -euo pipefail

image="${1:?usage: runtime-smoke.sh IMAGE_REF}"
container="indigo-runtime-smoke-$$"
started=0

cleanup() {
    local status=$?
    trap - EXIT
    if ((status != 0 && started)); then
        docker logs --tail 120 "${container}" >&2 || true
        docker exec "${container}" tail -n 40 /etc/services.d/code-server/log >&2 || true
    fi
    if ((started)); then
        docker rm --force "${container}" > /dev/null 2>&1 || true
    fi
    exit "${status}"
}
trap cleanup EXIT

docker run --detach \
    --name "${container}" \
    --hostname "${container}" \
    --restart no \
    --shm-size 1gb \
    --env INDIGO_ENABLE_INFERENCE=1 \
    --env INDIGO_ENABLE_FILESYSTEM=1 \
    --env INDIGO_ENABLE_RUST_ANALYZER=1 \
    --env INDIGO_ENABLE_OPENVIKING=0 \
    --env INDIGO_ENABLE_PINOKIO=0 \
    "${image}" sleep infinity > /dev/null
started=1

deadline=$((SECONDS + 240))
while ((SECONDS < deadline)); do
    if [[ "$(docker inspect --format '{{.State.Running}}' "${container}")" != true ]]; then
        echo "runtime smoke container exited before becoming healthy" >&2
        exit 1
    fi
    if docker exec "${container}" /healthcheck > /dev/null 2>&1; then
        break
    fi
    sleep 5
done

if ! docker exec "${container}" /healthcheck; then
    echo "runtime smoke services did not become healthy within 240 seconds" >&2
    exit 1
fi

docker exec "${container}" /bin/bash -c '
    test -r /home/nonroot/.config/llama-swap/config.yaml &&
    test -r /home/nonroot/.config/opencode/opencode.json &&
    command -v llama-swap &&
    command -v llama-server
' > /dev/null

mcp_request() {
    local port="$1"
    local payload="$2"

    docker exec "${container}" curl \
        --fail-with-body \
        --silent \
        --show-error \
        --max-time 30 \
        --header 'Content-Type: application/json' \
        --header 'Accept: application/json, text/event-stream' \
        --data "${payload}" \
        "http://127.0.0.1:${port}/mcp"
}

assert_mcp_response() {
    local request_id="$1"
    local result_field="$2"

    python3 -c '
import json
import sys

request_id = int(sys.argv[1])
result_field = sys.argv[2]
body = sys.stdin.read().strip()
events = [line[5:].strip() for line in body.splitlines() if line.startswith("data:")]
message = json.loads(events[-1] if events else body)
if message.get("jsonrpc") != "2.0" or message.get("id") != request_id:
    raise SystemExit(f"unexpected MCP response: {message}")
if "error" in message:
    raise SystemExit("MCP request failed: " + repr(message["error"]))
result = message.get("result")
if not isinstance(result, dict) or result_field not in result:
    raise SystemExit(f"MCP response has no {result_field}: {message}")
if result_field == "tools" and not result[result_field]:
    raise SystemExit("MCP server returned no tools")
' "${request_id}" "${result_field}"
}

initialize_payload='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"indigo-runtime-smoke","version":"1"}}}'
tools_payload='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
for endpoint in filesystem:11002 rust-analyzer:11003; do
    service="${endpoint%%:*}"
    port="${endpoint##*:}"
    echo "checking ${service} MCP initialization and tools/list"
    mcp_request "${port}" "${initialize_payload}" \
        | assert_mcp_response 1 serverInfo
    mcp_request "${port}" "${tools_payload}" \
        | assert_mcp_response 2 tools
done

docker stop --time 15 "${container}" > /dev/null
echo "runtime startup, MCP protocol, and shutdown passed for ${image}"
