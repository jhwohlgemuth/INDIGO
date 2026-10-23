#!/usr/bin/env bash
# Start a native MLX server for one Indigo Compose instance on Apple Silicon.
# shellcheck disable=SC2310 # loaded is intentionally used as a predicate.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_root="${INDIGO_MLX_STATE_DIR:-${repository_root}/.indigo/mlx}"
venv="${state_root}/venv"
instance="${INDIGO_MLX_INSTANCE:-indigo}"
port="${INDIGO_MLX_PORT:-10733}"
label="org.indigo.mlx.${instance}"
agent_dir="${state_root}/launchagents"
plist="${agent_dir}/${label}.plist"
launch_domain="gui/$(id -u)"
mlx_version=0.32.2

fail() {
    echo "error: $*" >&2
    exit 1
}
check_host() {
    [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || fail "MLX host mode requires an Apple Silicon Mac"
    local major
    major="$(sw_vers -productVersion)"
    major="${major%%.*}"
    ((major >= 14)) || fail "MLX host mode requires macOS 14 or later"
    [[ "${instance}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid instance name: ${instance}"
    if [[ ! "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        fail "invalid MLX port: ${port}"
    fi
}
select_python() {
    local candidate version
    local -a candidates=()
    if [[ -n "${INDIGO_MLX_PYTHON:-}" ]]; then
        candidates=("${INDIGO_MLX_PYTHON}")
    else
        candidates=(python3.13 python3.12 python3.11 python3)
    fi
    for candidate in "${candidates[@]}"; do
        command -v "${candidate}" > /dev/null 2>&1 || continue
        version="$("${candidate}" -c 'import platform,sys; print(int(sys.version_info >= (3,11) and platform.machine() == "arm64"))' 2> /dev/null)" || continue
        if [[ "${version}" == 1 ]]; then
            command -v "${candidate}"
            return
        fi
    done
    fail "install a native ARM64 Python 3.11 or newer, or set INDIGO_MLX_PYTHON"
}
loaded() {
    launchctl print "${launch_domain}/${label}" > /dev/null 2>&1
}
wait_ready() {
    local attempt
    for ((attempt = 0; attempt < 60; attempt++)); do
        if curl --fail --silent --max-time 2 "http://127.0.0.1:${port}/health" > /dev/null; then
            return
        fi
        sleep 5
    done
    fail "MLX did not become healthy on port ${port}; see ${state_root}/${instance}.err.log"
}
setup() {
    check_host
    local python
    python="$(select_python)"
    if [[ ! -x "${venv}/bin/python" ]]; then
        install -d -m 0755 "${state_root}"
        "${python}" -m venv "${venv}"
    fi
    "${venv}/bin/python" -m pip install --disable-pip-version-check "mlx-lm==${mlx_version}"
    "${venv}/bin/python" -c 'import mlx.core, mlx_lm; print("MLX host environment ready")'
}
start() {
    check_host
    local model="${1:-${MLX_MODEL:-}}"
    [[ -n "${model}" ]] || fail "set MLX_MODEL to a local MLX model directory or Hugging Face repo ID"
    if [[ -d "${model}" ]]; then
        model="$(cd "${model}" && pwd -P)"
    elif [[ "${model}" == /* || "${model}" == ./* || "${model}" == ../* ]]; then
        fail "MLX model directory does not exist: ${model}"
    fi
    if [[ ! -x "${venv}/bin/mlx_lm.server" ]]; then
        setup
    fi
    install -d -m 0755 "${agent_dir}"
    local new_plist="${plist}.tmp"
    "${venv}/bin/python" - "${new_plist}" "${venv}/bin/mlx_lm.server" "${model}" "${port}" "${state_root}/${instance}.log" "${state_root}/${instance}.err.log" "${label}" << 'PY'
import plistlib
import sys

path, executable, model, port, out_log, err_log, label = sys.argv[1:]
with open(path, "wb") as stream:
    plistlib.dump(
        {
            "Label": label,
            "ProgramArguments": [executable, "--model", model, "--host", "0.0.0.0", "--port", port],
            "RunAtLoad": True,
            "StandardOutPath": out_log,
            "StandardErrorPath": err_log,
        },
        stream,
    )
PY
    if loaded; then
        if ! cmp -s "${new_plist}" "${plist}"; then
            rm -f -- "${new_plist}"
            fail "MLX is running with different settings; run make down-mlx before changing the model or port"
        fi
        rm -f -- "${new_plist}"
    else
        mv -- "${new_plist}" "${plist}"
        launchctl bootstrap "${launch_domain}" "${plist}"
    fi
    wait_ready
    echo "MLX is ready at http://127.0.0.1:${port} for ${model}"
}
stop() {
    check_host
    if loaded; then
        launchctl bootout "${launch_domain}/${label}"
        echo "stopped ${label}"
    else
        echo "${label} is not running"
    fi
}
status() {
    check_host
    if loaded; then
        launchctl print "${launch_domain}/${label}"
    else
        echo "${label} is not running"
    fi
}
case "${1:-}" in
    setup) setup ;;
    start)
        shift
        start "$@"
        ;;
    stop) stop ;;
    status) status ;;
    *) fail "usage: $0 {setup|start|stop|status}" ;;
esac
