#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repository_root}"

for target in start run; do
    gpu="$(make --no-print-directory --dry-run "${target}" GPU=1)"
    cpu="$(make --no-print-directory --dry-run "${target}" GPU=0)"
    [[ "${gpu}" == *'--gpus all'* ]]
    [[ "${cpu}" != *'--gpus all'* ]]
    [[ "${cpu}" == *'--restart unless-stopped'* ]]
    [[ "${cpu}" == *'docker run'* ]]
    printf '%s\n' "${gpu}" | bash -n
    printf '%s\n' "${cpu}" | bash -n
done

echo 'standalone platform arguments passed'
