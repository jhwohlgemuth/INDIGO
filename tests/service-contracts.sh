#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-services-test.XXXXXX")"
background_pids=()
cleanup() {
    for pid in "${background_pids[@]}"; do
        kill "${pid}" 2> /dev/null || true
    done
    rm -rf -- "${fixture}"
}
trap cleanup EXIT
mkdir -p "${fixture}/bin"

cat > "${fixture}/bin/sleep" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != infinity ]]; then
    printf '%s\n' "$1" >> "${SLEEP_LOG}"
    /bin/sleep 0.05
fi
EOF
chmod 0755 "${fixture}/bin/sleep"

cat > "${fixture}/server" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SERVER_LOG}"
exit "${SERVER_EXIT:-0}"
EOF
chmod 0755 "${fixture}/server"

export PATH="${fixture}/bin:${PATH}"
export HOME="${fixture}/home"
export OPENVIKING_CONFIG_FILE="${HOME}/.openviking/ov.conf"
export OPENVIKING_SERVER_BIN="${fixture}/server"
export OPENVIKING_RETRY_INTERVAL=20
export SLEEP_LOG="${fixture}/sleep.log"
export SERVER_LOG="${fixture}/server.log"

service_dir="${repository_root}/rootfs/etc/services.d"
disabled_services=(inference-router mcp-filesystem mcp-rust-analyzer openviking pinokio)
disabled_flags=(INDIGO_ENABLE_INFERENCE INDIGO_ENABLE_FILESYSTEM INDIGO_ENABLE_RUST_ANALYZER INDIGO_ENABLE_OPENVIKING INDIGO_ENABLE_PINOKIO)
disabled_messages=(
    'Indigo inference is disabled'
    'Indigo Filesystem MCP is disabled'
    'Indigo Rust Analyzer MCP is disabled'
    'Indigo OpenViking is disabled'
    'Indigo Pinokio is disabled'
)
for index in "${!disabled_services[@]}"; do
    env "${disabled_flags[${index}]}=0" bash "${service_dir}/${disabled_services[${index}]}/run" > "${fixture}/out"
    [[ "$(< "${fixture}/out")" == "${disabled_messages[${index}]}" ]]
done

export INDIGO_ENABLE_OPENVIKING=1
bash "${service_dir}/openviking/run" > "${fixture}/missing.log" 2>&1 &
missing_pid=$!
background_pids+=("${missing_pid}")
for ((attempt = 0; attempt < 40; attempt++)); do
    if [[ -s "${fixture}/missing.log" ]]; then
        break
    fi
    /bin/sleep 0.05
done
kill "${missing_pid}" 2> /dev/null || true
wait "${missing_pid}" 2> /dev/null || true
[[ "$(< "${fixture}/missing.log")" == *'is waiting for'* ]]
[[ ! -e "${SERVER_LOG}" ]]

printf '{}\n' > "${OPENVIKING_CONFIG_FILE}"
export SERVER_EXIT=7
: > "${SERVER_LOG}"
: > "${SLEEP_LOG}"
bash "${service_dir}/openviking/run" > "${fixture}/invalid.log" 2>&1 &
invalid_pid=$!
background_pids+=("${invalid_pid}")
for ((attempt = 0; attempt < 40; attempt++)); do
    calls="$(wc -l < "${SERVER_LOG}")"
    if ((calls >= 2)); then
        break
    fi
    /bin/sleep 0.05
done
kill "${invalid_pid}" 2> /dev/null || true
wait "${invalid_pid}" 2> /dev/null || true
calls="$(wc -l < "${SERVER_LOG}")"
sleeps="$(wc -l < "${SLEEP_LOG}")"
((calls >= 2 && calls <= 6))
((sleeps >= 2 * (calls - 1)))
[[ "$(< "${fixture}/invalid.log")" == *'exited with status 7; retrying in 20s'* ]]

unset SERVER_EXIT
: > "${SERVER_LOG}"
bash "${service_dir}/openviking/run" > "${fixture}/valid.log" 2>&1
[[ "$(wc -l < "${SERVER_LOG}")" -eq 1 ]]
[[ "$(< "${SERVER_LOG}")" == *"--config ${OPENVIKING_CONFIG_FILE} --host 127.0.0.1 --port 1933"* ]]

echo 'service contracts passed'
