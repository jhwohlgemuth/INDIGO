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
    --env INDIGO_ENABLE_FILESYSTEM=0 \
    --env INDIGO_ENABLE_RUST_ANALYZER=0 \
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

docker stop --time 15 "${container}" > /dev/null
echo "runtime startup and shutdown passed for ${image}"
