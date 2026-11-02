#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-run-mounts.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT

container=indigo-run-contract
home=/home/nonroot

make --no-print-directory --dry-run --directory "${repository_root}" run \
    GPU=0 \
    CONTAINER="${container}" \
    IMAGE_REF=example.invalid/indigo:test > "${fixture}/run.txt"

grep -Fq -- "--volume \"${container}-llama-swap-config:${home}/.config/llama-swap\"" \
    "${fixture}/run.txt"

volume_count="$(grep -c -- '--volume ' "${fixture}/run.txt")"
if [[ "${volume_count}" -ne 9 ]]; then
    echo "expected make run to mount 9 persistent volumes, found ${volume_count}" >&2
    exit 1
fi

expected_volumes=(
    "workspace:${home}/dev"
    "models:${home}/.models"
    "llama-swap-config:${home}/.config/llama-swap"
    "openviking:${home}/.openviking"
    "pinokio:${home}/.pinokio"
    "opencode-config:${home}/.config/opencode"
    "opencode-data:${home}/.local/share/opencode"
    "codex:${home}/.codex"
    "cargo-cache:${home}/.cargo"
)
for volume in "${expected_volumes[@]}"; do
    grep -Fq -- "--volume \"${container}-${volume}\"" "${fixture}/run.txt"
done

echo 'standalone run mount contract passed'
