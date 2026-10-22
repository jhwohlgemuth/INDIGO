#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_user_site="$(python3 -m site --user-site)"
export PYTHONPATH="${python_user_site}${PYTHONPATH:+:${PYTHONPATH}}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-seeding-test.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT
defaults="${fixture}/defaults"
mkdir -p "${defaults}"
cp "${repository_root}/config/llama-swap/config.yaml" "${defaults}/llama-swap.yaml"
cp "${repository_root}/config/agents/opencode.json" "${defaults}/opencode.json"
cp "${repository_root}/config/agents/codex.toml" "${defaults}/codex.toml"

export INDIGO_DEFAULTS_DIR="${defaults}"
export INDIGO_DEFAULT_MODEL=demo
export INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/demo.gguf
export HOME="${fixture}/home"
seeder="${repository_root}/rootfs/etc/cont-init.d/20-indigo-agent-config"

bash "${seeder}"
router="${HOME}/.config/llama-swap/config.yaml"
agent="${HOME}/.config/opencode/opencode.json"
codex="${HOME}/.codex/config.toml"
[[ -f "${router}" && -f "${agent}" && -f "${codex}" ]]
python3 - "${router}" "${agent}" "${INDIGO_DEFAULT_MODEL_PATH}" << 'PY'
import json
import shlex
import sys

import yaml

with open(sys.argv[1], encoding="utf-8") as stream:
    router = yaml.safe_load(stream)
with open(sys.argv[2], encoding="utf-8") as stream:
    agent = json.load(stream)
assert "demo" in router["models"]
argv = shlex.split(router["models"]["demo"]["cmd"])
assert argv[argv.index("--model") + 1] == sys.argv[3]
assert agent["model"] == "indigo/demo"
PY

printf 'user-maintained router\n' > "${router}"
printf 'user-maintained agent\n' > "${agent}"
printf 'user-maintained codex\n' > "${codex}"
bash "${seeder}"
[[ "$(< "${router}")" == 'user-maintained router' ]]
[[ "$(< "${agent}")" == 'user-maintained agent' ]]
[[ "$(< "${codex}")" == 'user-maintained codex' ]]

hostile_paths=(
    '/home/nonroot/.models/bad path'
    '/home/nonroot/.models/bad|path'
    '/home/nonroot/.models/bad&path'
    '/home/nonroot/.models/bad\path'
    "/home/nonroot/.models/bad'path"
    "/home/nonroot/.models/bad\$path"
)
for index in "${!hostile_paths[@]}"; do
    export HOME="${fixture}/hostile-${index}"
    export INDIGO_DEFAULT_MODEL_PATH="${hostile_paths[${index}]}"
    if bash "${seeder}" > "${fixture}/out" 2> "${fixture}/err"; then
        echo "accepted hostile model path: ${INDIGO_DEFAULT_MODEL_PATH}" >&2
        exit 1
    fi
    [[ ! -e "${HOME}/.config/llama-swap/config.yaml" ]]
    [[ ! -e "${HOME}/.config/opencode/opencode.json" ]]
    [[ ! -e "${HOME}/.codex/config.toml" ]]
done

export HOME="${fixture}/missing-source"
export INDIGO_DEFAULT_MODEL_PATH=/home/nonroot/.models/demo.gguf
export INDIGO_DEFAULTS_DIR="${fixture}/missing-defaults"
mkdir -p "${INDIGO_DEFAULTS_DIR}"
if bash "${seeder}" > "${fixture}/out" 2> "${fixture}/err"; then
    echo 'accepted missing source template' >&2
    exit 1
fi
[[ ! -e "${HOME}/.config/llama-swap/config.yaml" ]]
for leftover in "${HOME}/.config/llama-swap/"*.tmp.*; do
    [[ ! -e "${leftover}" ]]
done

export INDIGO_DEFAULTS_DIR="${defaults}"
export HOME="${fixture}/symlink-home"
mkdir -p "${HOME}/.config/llama-swap"
ln -s "${fixture}/missing-router" "${HOME}/.config/llama-swap/config.yaml"
bash "${seeder}"
[[ -L "${HOME}/.config/llama-swap/config.yaml" ]]
[[ ! -e "${fixture}/missing-router" ]]

echo 'config seeding contract passed'
