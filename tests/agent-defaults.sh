#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-agent-defaults.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT
defaults="${fixture}/defaults"
mkdir -p "${defaults}"
cp "${repository_root}/config/llama-swap/config.yaml" "${defaults}/llama-swap.yaml"
cp "${repository_root}/config/llama-swap/mlx.yaml" "${defaults}/llama-swap-mlx.yaml"
cp "${repository_root}/config/agents/opencode.json" "${defaults}/opencode.json"
cp "${repository_root}/config/agents/opencode.mlx.json" "${defaults}/opencode-mlx.json"
cp "${repository_root}/config/agents/codex.toml" "${defaults}/codex.toml"

export INDIGO_DEFAULTS_DIR="${defaults}"
export INDIGO_DEFAULT_MODEL=demo
export INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/demo.gguf
seeder="${repository_root}/rootfs/etc/cont-init.d/20-indigo-agent-config"

assert_mcp_flags() {
    local config="$1"
    local filesystem="$2"
    local rust_analyzer="$3"
    local openviking="$4"
    python3 - "${config}" "${filesystem}" "${rust_analyzer}" "${openviking}" << 'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    config = json.load(stream)
expected = [value == "true" for value in sys.argv[2:]]
actual = [
    config["mcp"]["filesystem"]["enabled"],
    config["mcp"]["rust-analyzer"]["enabled"],
    config["mcp"]["openviking"]["enabled"],
]
assert actual == expected, (actual, expected)
PY
}

export HOME="${fixture}/direct-image"
unset INDIGO_ENABLE_FILESYSTEM INDIGO_ENABLE_RUST_ANALYZER INDIGO_ENABLE_OPENVIKING
bash "${seeder}"
assert_mcp_flags "${HOME}/.config/opencode/opencode.json" false false false

export HOME="${fixture}/full-stack"
export INDIGO_ENABLE_FILESYSTEM=1
export INDIGO_ENABLE_RUST_ANALYZER=true
export INDIGO_ENABLE_OPENVIKING=yes
bash "${seeder}"
agent="${HOME}/.config/opencode/opencode.json"
assert_mcp_flags "${agent}" true true true

export HOME="${fixture}/mlx"
export INDIGO_ROUTER_MODE=mlx
export INDIGO_ENABLE_FILESYSTEM=1
export INDIGO_ENABLE_RUST_ANALYZER=0
export INDIGO_ENABLE_OPENVIKING=on
bash "${seeder}"
assert_mcp_flags "${HOME}/.config/opencode/opencode.json" true false true
unset INDIGO_ROUTER_MODE

export HOME="${fixture}/full-stack"
printf 'user-maintained agent\n' > "${agent}"
export INDIGO_ENABLE_FILESYSTEM=0
export INDIGO_ENABLE_RUST_ANALYZER=0
export INDIGO_ENABLE_OPENVIKING=0
bash "${seeder}"
[[ "$(< "${agent}")" == 'user-maintained agent' ]]

echo 'agent defaults contract passed'
