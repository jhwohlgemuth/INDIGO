#! /bin/bash
set -euo pipefail

requires \
    cmake \
    git \
    nvcc \
    ldd

# The llama.cpp executables are dynamically linked against libllama, libggml,
# and the CUDA backend, so the shared objects are installed next to the
# binaries. Removing the build tree without them leaves llama-server unable to
# load, which only fails when a model is served.
install_shared_objects() {
    local -a objects=()
    mapfile -t objects < <(find "${BUILD_DIRECTORY}" -type f -name '*.so*')
    if [[ ${#objects[@]} -eq 0 ]]; then
        echo "error: no shared objects found under ${BUILD_DIRECTORY}" >&2
        exit 1
    fi
    install -d -m 0755 "${LIB_DIRECTORY}"
    install -m 0755 "${objects[@]}" "${LIB_DIRECTORY}/"

    # GGML_BACKEND_DL builds discover their backends in the directory holding
    # the executable, so the backend objects belong beside the binaries as well
    # as on the library path. Without them llama-server still starts but fails
    # the first model load with "no backends are loaded".
    install -m 0755 "${LIB_DIRECTORY}"/libggml-*.so /usr/local/bin/
}

# A build that silently drops its libraries still produces an image that looks
# healthy, so fail here instead of at first model load.
verify_binaries() {
    local binary
    for binary in llama-cli llama-server; do
        if ldd "/usr/local/bin/${binary}" | grep -q 'not found'; then
            echo "error: ${binary} has unresolved shared libraries" >&2
            ldd "/usr/local/bin/${binary}" | grep 'not found' >&2
            exit 1
        fi
    done
    if [[ ! -f "${LIB_DIRECTORY}/libggml-cuda.so" ]]; then
        echo "error: CUDA backend was not built; expected ${LIB_DIRECTORY}/libggml-cuda.so" >&2
        exit 1
    fi
    if ! compgen -G '/usr/local/bin/libggml-*.so' > /dev/null; then
        echo "error: no ggml backends beside the binaries; model loads will fail" >&2
        exit 1
    fi
    if ! /usr/local/bin/llama-server --version > /dev/null 2>&1; then
        echo "error: llama-server cannot report its version" >&2
        exit 1
    fi
}

main() {
    local -a CMAKE_ARGS_ARRAY=()
    local NVCC_BIN
    local SRC_DIRECTORY="${HOME}/llamacpp"
    local BUILD_DIRECTORY="${SRC_DIRECTORY}/build"
    local LIB_DIRECTORY=/usr/local/lib
    NVCC_BIN="$(command -v nvcc)"
    if [[ -n "${CMAKE_ARGS:-}" ]]; then
        # Split optional CMAKE_ARGS into an array so arguments are passed safely.
        read -r -a CMAKE_ARGS_ARRAY <<< "${CMAKE_ARGS}"
    fi
    git clone https://github.com/ggml-org/llama.cpp.git "${SRC_DIRECTORY}"
    pushd "${SRC_DIRECTORY}" > /dev/null || exit
    cmake -B build \
        -DGGML_NATIVE=OFF \
        -DGGML_CUDA=ON \
        -DGGML_BACKEND_DL=ON \
        -DGGML_CPU_ALL_VARIANTS=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DCMAKE_CUDA_COMPILER="${NVCC_BIN}" \
        "${CMAKE_ARGS_ARRAY[@]}" \
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
        -DCMAKE_BUILD_TYPE=Release \
        .
    cmake --build build --config Release -j"$(nproc)"
    popd > /dev/null || exit

    install_shared_objects
    install -m 0755 "${BUILD_DIRECTORY}/bin/llama-cli" /usr/local/bin/llama-cli
    install -m 0755 "${BUILD_DIRECTORY}/bin/llama-server" /usr/local/bin/llama-server
    verify_binaries
    rm -rf "${SRC_DIRECTORY}"
}
main "$@"
