#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_script="${repository_root}/scripts/build_llama_cpp_from_source.sh"
dockerfile="${repository_root}/Dockerfile"
fixture="$(mktemp -d /tmp/indigo-build-inputs.XXXXXX)"
trap 'rm -rf "${fixture}"' EXIT

expected_commit=8642541b255bfb5dc39cd351a178be09013a55d6
expected_code_server_version=4.143.1
expected_code_server_digest=sha256:377b66bec5645510ed52549bb00e648c273edc604d230a3f90fd2b2433afcb97
other_commit=0000000000000000000000000000000000000000
llama_commit_argument="\${LLAMA_CPP_COMMIT}"
code_server_version_argument="\${CODE_SERVER_VERSION}"
code_server_digest_argument="\${CODE_SERVER_DIGEST}"
user_name_argument="\${USER_NAME}"

grep -Fqx "ARG LLAMA_CPP_COMMIT=${expected_commit}" "${dockerfile}"
grep -Fqx 'ARG LLAMA_CPP_COMMIT' "${dockerfile}"
grep -Fqx "LABEL org.indigo.llama.cpp.revision=\"${llama_commit_argument}\"" "${dockerfile}"
grep -Fq "&& LLAMA_CPP_COMMIT=\"${llama_commit_argument}\" \\" "${dockerfile}"
grep -Fqx "ARG CODE_SERVER_VERSION=${expected_code_server_version}" "${dockerfile}"
grep -Fqx "ARG CODE_SERVER_DIGEST=${expected_code_server_digest}" "${dockerfile}"
grep -Fqx "FROM ghcr.io/coder/code-server:${code_server_version_argument}@${code_server_digest_argument} AS code-server" \
    "${dockerfile}"
grep -Fqx "COPY --from=code-server --chown=${user_name_argument}:${user_name_argument} /usr/lib/code-server /app/code-server" \
    "${dockerfile}"

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
    -C)
        shift 2
        case "${1:-}" in
            init)
                ;;
            remote)
                [[ "${2:-}" == add && "${3:-}" == origin ]]
                ;;
            fetch)
                [[ "${2:-}" == --depth && "${3:-}" == 1 && "${4:-}" == origin ]]
                ;;
            checkout)
                [[ "${2:-}" == --detach && "${3:-}" == FETCH_HEAD ]]
                ;;
            *)
                echo "unexpected fake git -C invocation: $*" >&2
                exit 1
                ;;
        esac
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
grep -Fqx -- "-C ${fixture}/home-${expected_commit}/llamacpp init" \
    "${fixture}/git.log"
grep -Fqx -- "-C ${fixture}/home-${expected_commit}/llamacpp remote add origin https://github.com/ggml-org/llama.cpp.git" \
    "${fixture}/git.log"
grep -Fqx -- "-C ${fixture}/home-${expected_commit}/llamacpp fetch --depth 1 origin ${expected_commit}" \
    "${fixture}/git.log"
grep -Fqx -- "-C ${fixture}/home-${expected_commit}/llamacpp checkout --detach FETCH_HEAD" \
    "${fixture}/git.log"
grep -Fqx 'rev-parse HEAD' "${fixture}/git.log"

run_checkout_fixture "${other_commit}" "${fixture}/mismatch.err"
[[ ${fixture_status} -eq 1 ]]
grep -Fq "checked out llama.cpp revision ${other_commit}, expected ${expected_commit}" \
    "${fixture}/mismatch.err"

echo "build input contract passed"
