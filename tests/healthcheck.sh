#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-health-test.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT
mkdir -p "${fixture}/bin"

cat > "${fixture}/bin/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
sleep "${TEST_CURL_DELAY:-0}"
if [[ "${TEST_CURL_FAIL:-0}" == 1 ]]; then
    exit 22
fi
EOF
chmod 0755 "${fixture}/bin/curl"

export PATH="${fixture}/bin:${PATH}"
export OPENVIKING_CONFIG_FILE="${fixture}/ov.conf"
export INDIGO_ENABLE_INFERENCE=0
export INDIGO_ENABLE_FILESYSTEM=0
export INDIGO_ENABLE_RUST_ANALYZER=0
export INDIGO_ENABLE_OPENVIKING=0
export INDIGO_ENABLE_PINOKIO=0

if ! bash "${repository_root}/scripts/healthcheck.sh" > "${fixture}/out" 2> "${fixture}/err"; then
    cat "${fixture}/out" "${fixture}/err" >&2
    exit 1
fi
expected=$'OK: code-server (https://localhost:1337)\nOK: verdaccio (https://localhost:4873)\nOK: jupyter (https://localhost:13337)\nOK: marimo (http://localhost:13338)'
[[ "$(< "${fixture}/out")" == "${expected}" ]]
[[ ! -s "${fixture}/err" ]]

export INDIGO_ENABLE_INFERENCE=1
export INDIGO_ENABLE_FILESYSTEM=1
export INDIGO_ENABLE_RUST_ANALYZER=1
export INDIGO_ENABLE_OPENVIKING=1
export INDIGO_ENABLE_PINOKIO=1
export TEST_CURL_DELAY=5
export TEST_CURL_FAIL=1
started="$(date +%s)"
if bash "${repository_root}/scripts/healthcheck.sh" > "${fixture}/out" 2> "${fixture}/err"; then
    echo 'expected failed probes to fail the health check' >&2
    exit 1
fi
elapsed="$(($(date +%s) - started))"
((elapsed < 10))
[[ "$(< "${fixture}/out")" == "WAIT: openviking (${OPENVIKING_CONFIG_FILE} is not configured)" ]]
failures=()
while IFS= read -r line; do
    failures+=("${line}")
done < "${fixture}/err"
expected_names=(code-server verdaccio jupyter marimo inference-router filesystem-mcp rust-analyzer-mcp pinokio pinokio-proxy)
[[ "${#failures[@]}" -eq "${#expected_names[@]}" ]]
for index in "${!expected_names[@]}"; do
    [[ "${failures[${index}]}" == "FAIL: ${expected_names[${index}]} ("* ]]
done

printf '{}\n' > "${OPENVIKING_CONFIG_FILE}"
unset TEST_CURL_DELAY TEST_CURL_FAIL
bash "${repository_root}/scripts/healthcheck.sh" > "${fixture}/out" 2> "${fixture}/err"
[[ "$(< "${fixture}/out")" == *'OK: openviking (http://localhost:1933/health)'* ]]
[[ "$(< "${fixture}/out")" != *'WAIT: openviking'* ]]
[[ ! -s "${fixture}/err" ]]

echo 'healthcheck contract passed'
