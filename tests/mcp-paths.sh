#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-mcp-paths.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT

fake_gateway="${fixture}/fake-gateway"
fake_child="${fixture}/fake-child"
gateway_log="${fixture}/gateway.argv"
child_log="${fixture}/child.argv"
marker="${fixture}/command-ran"
hostile_workspace="${fixture}/workspace & pipe | apostrophe ' dollar \$(touch ${marker}) backslash \\"

cat > "${fake_gateway}" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" > "${GATEWAY_ARGV_LOG}"
EOF
chmod 0755 "${fake_gateway}"

cat > "${fake_child}" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" > "${CHILD_ARGV_LOG}"
EOF
chmod 0755 "${fake_child}"

assert_nul_argv() {
    local log="$1"
    shift
    python3 - "${log}" "$@" << 'PY'
import pathlib
import sys

actual = pathlib.Path(sys.argv[1]).read_bytes().split(b"\0")
if actual[-1] == b"":
    actual.pop()
actual = [value.decode() for value in actual]
expected = sys.argv[2:]
if actual != expected:
    raise SystemExit(f"argv mismatch: expected {expected!r}, got {actual!r}")
PY
}

exercise_service() {
    local service="$1"
    local workspace_variable="$2"
    local binary_path="$3"
    local expected_child="/etc/services.d/${service}/child"
    local source_dir="${repository_root}/rootfs/etc/services.d/${service}"
    local run_copy="${fixture}/${service}-run"
    local child_copy="${fixture}/${service}-child"
    local port

    case "${service}" in
        mcp-filesystem) port=11002 ;;
        mcp-rust-analyzer) port=11003 ;;
        *)
            echo "unknown service: ${service}" >&2
            return 1
            ;;
    esac

    sed "s|/opt/mcp/node/bin/supergateway|${fake_gateway}|" \
        "${source_dir}/run" > "${run_copy}"
    sed "s|${binary_path}|${fake_child}|" \
        "${source_dir}/child" > "${child_copy}"
    chmod 0755 "${run_copy}" "${child_copy}"

    GATEWAY_ARGV_LOG="${gateway_log}" \
        INDIGO_ENABLE_FILESYSTEM=1 \
        INDIGO_ENABLE_RUST_ANALYZER=1 \
        MCP_FILESYSTEM_PORT="${port}" \
        MCP_RUST_ANALYZER_PORT="${port}" \
        env "${workspace_variable}=${hostile_workspace}" bash "${run_copy}"
    assert_nul_argv "${gateway_log}" \
        --stdio "${expected_child}" \
        --outputTransport streamableHttp \
        --port "${port}" \
        --healthEndpoint /healthz

    CHILD_ARGV_LOG="${child_log}" \
        env "${workspace_variable}=${hostile_workspace}" bash "${child_copy}"
    assert_nul_argv "${child_log}" "${hostile_workspace}"

    [[ -d "${hostile_workspace}" ]]
    [[ ! -e "${marker}" ]]
}

exercise_service mcp-filesystem MCP_FILESYSTEM_WORKSPACE \
    /opt/mcp/node/bin/mcp-server-filesystem
exercise_service mcp-rust-analyzer RUST_ANALYZER_WORKSPACE \
    /usr/local/bin/rust-analyzer-mcp

echo 'MCP workspace argument contract passed'
