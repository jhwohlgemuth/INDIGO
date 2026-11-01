#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_script="${repository_root}/scripts/build_llama_cpp_from_source.sh"
dockerfile="${repository_root}/Dockerfile"
fixture="$(mktemp -d /tmp/indigo-build-inputs.XXXXXX)"
trap 'rm -rf "${fixture}"' EXIT

expected_commit=8642541b255bfb5dc39cd351a178be09013a55d6
other_commit=0000000000000000000000000000000000000000
llama_commit_argument="\${LLAMA_CPP_COMMIT}"

grep -Fqx "ARG LLAMA_CPP_COMMIT=${expected_commit}" "${dockerfile}"
grep -Fqx 'ARG LLAMA_CPP_COMMIT' "${dockerfile}"
grep -Fqx "LABEL org.indigo.llama.cpp.revision=\"${llama_commit_argument}\"" "${dockerfile}"
grep -Fq "&& LLAMA_CPP_COMMIT=\"${llama_commit_argument}\" \\" "${dockerfile}"

if LLAMA_CPP_COMMIT=main INDIGO_LLAMA_BACKEND=cpu bash "${build_script}" \
    > "${fixture}/invalid.out" 2> "${fixture}/invalid.err"; then
    echo "invalid llama.cpp revision unexpectedly passed" >&2
    exit 1
fi
grep -Fq 'LLAMA_CPP_COMMIT must be a full lowercase 40-character commit SHA' \
    "${fixture}/invalid.err"

fake_bin="${fixture}/bin"
mkdir -p "${fake_bin}"

for command in requires ldd; do
    cat > "${fake_bin}/${command}" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${fake_bin}/${command}"
done

cat > "${fake_bin}/cmake" << 'EOF'
#!/usr/bin/env bash
exit 73
EOF
chmod +x "${fake_bin}/cmake"

cat > "${fake_bin}/git" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${GIT_LOG}"
case "${1:-}" in
    clone)
        mkdir -p "${@: -1}"
        ;;
    checkout)
        [[ "${2:-}" == --detach ]]
        ;;
    rev-parse)
        [[ "${2:-}" == HEAD ]]
        printf '%s\n' "${FAKE_GIT_HEAD}"
        ;;
    *)
        echo "unexpected fake git invocation: $*" >&2
        exit 1
        ;;
esac
EOF
chmod +x "${fake_bin}/git"

run_checkout_fixture() {
    local fake_head="$1"
    local stderr_file="$2"
    local home_dir="${fixture}/home-$1"
    mkdir -p "${home_dir}"
    : > "${fixture}/git.log"
    set +e
    PATH="${fake_bin}:${PATH}" \
        HOME="${home_dir}" \
        GIT_LOG="${fixture}/git.log" \
        FAKE_GIT_HEAD="${fake_head}" \
        LLAMA_CPP_COMMIT="${expected_commit}" \
        INDIGO_LLAMA_BACKEND=cpu \
        bash "${build_script}" > "${fixture}/checkout.out" 2> "${stderr_file}"
    fixture_status=$?
    set -e
}

run_checkout_fixture "${expected_commit}" "${fixture}/checkout.err"
[[ ${fixture_status} -eq 73 ]]
grep -Fqx "clone https://github.com/ggml-org/llama.cpp.git ${fixture}/home-${expected_commit}/llamacpp" \
    "${fixture}/git.log"
grep -Fqx "checkout --detach ${expected_commit}" "${fixture}/git.log"
grep -Fqx 'rev-parse HEAD' "${fixture}/git.log"

run_checkout_fixture "${other_commit}" "${fixture}/mismatch.err"
[[ ${fixture_status} -eq 1 ]]
grep -Fq "checked out llama.cpp revision ${other_commit}, expected ${expected_commit}" \
    "${fixture}/mismatch.err"

echo "build input contract passed"
