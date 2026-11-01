#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
results_dir="${INDIGO_BENCHMARK_DIR:-${repository_root}/.indigo/benchmarks}"
sample_count="${INDIGO_BENCHMARK_SAMPLES:-6}"
sample_interval="${INDIGO_BENCHMARK_INTERVAL:-10}"

usage() {
    cat << 'EOF'
Usage:
  scripts/benchmark.sh host
  scripts/benchmark.sh build LABEL IMAGE [docker build arguments ...]
  scripts/benchmark.sh idle LABEL CONTAINER

Results are written below INDIGO_BENCHMARK_DIR (default:
.indigo/benchmarks). build passes every argument after IMAGE to
`docker build`; callers must supply the context argument. idle samples an
already-running container and never starts, stops, or removes it.

Optional environment:
  INDIGO_BENCHMARK_SAMPLES    Idle samples to collect (default: 6)
  INDIGO_BENCHMARK_INTERVAL   Seconds between idle samples (default: 10)
  INDIGO_POWER_READER         Executable that prints host power in watts
EOF
}

require_positive_integer() {
    local name="$1"
    local value="$2"
    if [[ ! "${value}" =~ ^[1-9][0-9]*$ ]]; then
        echo "error: ${name} must be a positive integer" >&2
        exit 2
    fi
}

require_label() {
    local label="$1"
    if [[ ! "${label}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo 'error: LABEL may contain only letters, numbers, dots, underscores, and hyphens' >&2
        exit 2
    fi
}

write_common_metadata() {
    local destination="$1"
    local docker_versions docker_host
    local client_version server_version api_version
    local host_name host_os host_arch host_cpus host_memory storage_driver

    docker_versions="$(docker version --format '{{.Client.Version}}|{{.Server.Version}}|{{.Server.APIVersion}}')"
    IFS='|' read -r client_version server_version api_version <<< "${docker_versions}"
    docker_host="$(docker info --format '{{.Name}}|{{.OperatingSystem}}|{{.Architecture}}|{{.NCPU}}|{{.MemTotal}}|{{.Driver}}')"
    IFS='|' read -r host_name host_os host_arch host_cpus host_memory storage_driver <<< "${docker_host}"
    {
        printf 'captured_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'repository_commit=%s\n' "$(git -C "${repository_root}" rev-parse HEAD)"
        printf 'repository_dirty=%s\n' "$(git -C "${repository_root}" status --porcelain | awk 'END { print (NR > 0 ? "true" : "false") }')"
        printf 'docker_context=%s\n' "$(docker context show)"
        printf 'docker_client=%s\ndocker_server=%s\ndocker_api=%s\n' \
            "${client_version}" "${server_version}" "${api_version}"
        printf 'docker_host=%s\nhost_os=%s\nhost_arch=%s\nhost_cpus=%s\nhost_memory_bytes=%s\nstorage_driver=%s\n' \
            "${host_name}" "${host_os}" "${host_arch}" "${host_cpus}" "${host_memory}" "${storage_driver}"
    } > "${destination}"
}

record_host() {
    mkdir -p "${results_dir}"
    write_common_metadata "${results_dir}/host.env"
    printf 'wrote %s\n' "${results_dir}/host.env"
}

record_build() {
    local label="$1"
    local image="$2"
    shift 2
    require_label "${label}"
    if [[ $# -eq 0 ]]; then
        echo 'error: build requires docker build arguments, including a context' >&2
        exit 2
    fi

    local build_dir="${results_dir}/build-${label}"
    local started_at finished_at elapsed image_id image_size image_digest
    mkdir -p "${build_dir}"
    write_common_metadata "${build_dir}/metadata.env"
    printf 'label=%s\nimage=%s\n' "${label}" "${image}" >> "${build_dir}/metadata.env"
    printf '%q ' docker build --tag "${image}" "$@" > "${build_dir}/command.txt"
    printf '\n' >> "${build_dir}/command.txt"

    started_at="$(date +%s)"
    set +e
    docker build --progress plain --metadata-file "${build_dir}/build-metadata.json" \
        --tag "${image}" "$@" 2>&1 | tee "${build_dir}/build.log"
    build_status=${PIPESTATUS[0]}
    set -e
    finished_at="$(date +%s)"
    elapsed=$((finished_at - started_at))
    printf 'elapsed_seconds=%s\nbuild_status=%s\n' "${elapsed}" "${build_status}" >> "${build_dir}/metadata.env"
    if [[ ${build_status} -ne 0 ]]; then
        exit "${build_status}"
    fi

    image_id="$(docker image inspect --format '{{.Id}}' "${image}")"
    image_size="$(docker image inspect --format '{{.Size}}' "${image}")"
    image_digest="$(docker image inspect --format '{{index .RepoDigests 0}}' "${image}" 2> /dev/null || true)"
    {
        printf 'image_id=%s\n' "${image_id}"
        printf 'image_digest=%s\n' "${image_digest:-unavailable-local-image}"
        printf 'image_size_bytes=%s\n' "${image_size}"
    } >> "${build_dir}/metadata.env"
    printf 'build %s completed in %ss; image size %s bytes\n' "${label}" "${elapsed}" "${image_size}"
}

read_power() {
    if [[ -z "${INDIGO_POWER_READER:-}" ]]; then
        printf 'unavailable'
        return
    fi
    if [[ ! -x "${INDIGO_POWER_READER}" ]]; then
        echo "error: INDIGO_POWER_READER is not executable: ${INDIGO_POWER_READER}" >&2
        exit 2
    fi
    "${INDIGO_POWER_READER}"
}

record_idle() {
    local label="$1"
    local container="$2"
    require_label "${label}"
    require_positive_integer INDIGO_BENCHMARK_SAMPLES "${sample_count}"
    require_positive_integer INDIGO_BENCHMARK_INTERVAL "${sample_interval}"

    local idle_dir="${results_dir}/idle-${label}"
    local sample stats power
    mkdir -p "${idle_dir}"
    write_common_metadata "${idle_dir}/metadata.env"
    if [[ "$(docker inspect --format '{{.State.Running}}' "${container}")" != true ]]; then
        echo "error: container is not running: ${container}" >&2
        exit 2
    fi
    docker inspect "${container}" > "${idle_dir}/container-inspect.json"
    printf 'label=%s\ncontainer=%s\nsamples=%s\ninterval_seconds=%s\n' \
        "${label}" "${container}" "${sample_count}" "${sample_interval}" >> "${idle_dir}/metadata.env"
    printf 'captured_utc\tcpu_percent\tmemory_usage\tmemory_percent\tnetwork_io\tblock_io\tpids\thost_power_watts\n' \
        > "${idle_dir}/samples.tsv"
    for ((sample = 1; sample <= sample_count; sample++)); do
        stats="$(docker stats --no-stream --format '{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}' "${container}")"
        power="$(read_power)"
        printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${stats}" "${power}" >> "${idle_dir}/samples.tsv"
        if ((sample < sample_count)); then
            sleep "${sample_interval}"
        fi
    done
    printf 'wrote %s\n' "${idle_dir}/samples.tsv"
}

command="${1:-}"
case "${command}" in
    host)
        [[ $# -eq 1 ]] || {
            usage >&2
            exit 2
        }
        record_host
        ;;
    build)
        [[ $# -ge 4 ]] || {
            usage >&2
            exit 2
        }
        shift
        record_build "$@"
        ;;
    idle)
        [[ $# -eq 3 ]] || {
            usage >&2
            exit 2
        }
        shift
        record_idle "$@"
        ;;
    -h | --help | help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
