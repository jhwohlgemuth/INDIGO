#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${repository_root}/scripts/check.sh"
base="${repository_root}/.env"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-port-contract.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT

replace_value() {
    local source="$1"
    local target="$2"
    local key="$3"
    local value="$4"
    awk -v key="${key}" -v value="${value}" '
        index($0, key "=") == 1 { $0 = key "=" value }
        { print }
    ' "${source}" > "${target}"
}

render_compose() {
    local env_file="$1"
    shift
    (
        cd "${repository_root}"
        env "$@" docker compose --env-file "${env_file}" \
            -f compose.yaml config
    )
}

assert_port_mapping() {
    local rendered="$1"
    local published="$2"
    awk -v expected="${published}" '
        $1 == "-" && $2 == "mode:" { target = ""; host = "" }
        $1 == "target:" { target = $2 }
        $1 == "published:" {
            host = $2
            gsub(/"/, "", host)
        }
        $1 == "protocol:" && target == "10732" && host == expected { found = 1 }
        END { exit !found }
    ' "${rendered}"
}

alternate="${fixture}/alternate.env"
replace_value "${base}" "${alternate}" INFERENCE_PUBLISHED_PORT 20732
"${checker}" "${alternate}" > /dev/null
render_compose "${alternate}" > "${fixture}/alternate.yaml"
assert_port_mapping "${fixture}/alternate.yaml" 20732
grep -Fq 'listen: "http://0.0.0.0:10732"' \
    "${repository_root}/config/llama-swap/config.yaml"
grep -Fq '"baseURL": "http://127.0.0.1:10732/v1"' \
    "${repository_root}/config/agents/opencode.json"

echo 'internal inference port contract passed'
