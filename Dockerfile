ARG NOTEBOOK_VERSION=1.0.5
ARG NOTEBOOK_DIGEST=sha256:c3256bd1d46ffd71f6c7b95cc0da7cca1c2ddc417070f3a7622bd557838be7dd
ARG CODE_SERVER_VERSION=4.143.1
ARG CODE_SERVER_DIGEST=sha256:377b66bec5645510ed52549bb00e648c273edc604d230a3f90fd2b2433afcb97
ARG PINOKIO_NODE_VERSION=20
ARG PINOKIO_NODE_DIGEST=sha256:8f693eaa7e0a8e71560c9a82b55fd54c2ae920a2ba5d2cde28bac7d1c01c9ba5
ARG PINOKIO_COMMIT=2c39f9fe9c40c985e03b13ab8a48ead908139b39
ARG CADDY_VERSION=2.9.1
ARG CADDY_DIGEST=sha256:748016f285ed8c43a9ce6e3aed6d92d3009d90ca41157950880f40beaf3ff62b
ARG MCP_NODE_VERSION=24
ARG MCP_NODE_DIGEST=sha256:c86ecead9e55a5210ac1727de38a4ca840bf03dcaf34dc9749addbf383b1920c
ARG RUST_VERSION=1.90
ARG RUST_DIGEST=sha256:3914072ca0c3b8aad871db9169a651ccfce30cf58303e5d6f2db16d1d8a7e58f
ARG LLAMA_CPP_COMMIT=8642541b255bfb5dc39cd351a178be09013a55d6

FROM node:${PINOKIO_NODE_VERSION}@${PINOKIO_NODE_DIGEST} AS pinokio-source
ARG PINOKIO_COMMIT
ADD https://github.com/pinokiocomputer/pinokiod/archive/${PINOKIO_COMMIT}.tar.gz /tmp/pinokio.tar.gz
RUN mkdir /src \
    && tar -xzf /tmp/pinokio.tar.gz --strip-components=1 -C /src \
    && rm /tmp/pinokio.tar.gz \
    && sed -i '/  async installed() {/a\    if (process.env.PINOKIO_SYSTEM_CADDY === "1") return true' \
        /src/kernel/bin/caddy.js

FROM node:${PINOKIO_NODE_VERSION}@${PINOKIO_NODE_DIGEST} AS pinokio-build
WORKDIR /app
RUN apt-get update \
    && apt-get install --yes --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY --from=pinokio-source /src/package.json /src/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM caddy:${CADDY_VERSION}@${CADDY_DIGEST} AS pinokio-caddy

FROM ghcr.io/coder/code-server:${CODE_SERVER_VERSION}@${CODE_SERVER_DIGEST} AS code-server

FROM node:${MCP_NODE_VERSION}-bookworm-slim@${MCP_NODE_DIGEST} AS mcp-node
ARG SUPERGATEWAY_VERSION=3.4.3
ARG FILESYSTEM_MCP_VERSION=2026.7.10
RUN npm install --global --omit=dev \
        "supergateway@${SUPERGATEWAY_VERSION}" \
        "@modelcontextprotocol/server-filesystem@${FILESYSTEM_MCP_VERSION}" \
    && npm cache clean --force

FROM rust:${RUST_VERSION}-bookworm@${RUST_DIGEST} AS rust-toolchain
ARG RUST_ANALYZER_MCP_VERSION=0.4.0
RUN rustup component add rust-analyzer rust-src \
    && cargo install --locked --version "${RUST_ANALYZER_MCP_VERSION}" rust-analyzer-mcp

FROM ghcr.io/jhwohlgemuth/notebook:${NOTEBOOK_VERSION}@${NOTEBOOK_DIGEST}
ARG LLAMA_CPP_COMMIT
#
# %labels
#
LABEL author="Jason Wohlgemuth"
LABEL org.opencontainers.image.source="https://github.com/jhwohlgemuth/indigo"
LABEL org.opencontainers.image.title="Indigo"
LABEL org.opencontainers.image.description="A local workshop for agentic software development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.indigo.llama.cpp.revision="${LLAMA_CPP_COMMIT}"
#
# %arguments
#
ARG USER_NAME=nonroot
ARG HOME="/home/${USER_NAME}"
ARG MODEL_DIRECTORY="${HOME}/.models"
ARG CONTEXT_SIZE=0
ARG OPENVIKING_VERSION=0.4.17
ARG HF_VERSION=2.4.0
ARG LLAMA_SWAP_VERSION=269
ARG INDIGO_LLAMA_BACKEND=cuda
ARG INDIGO_LLAMA_BUILD_JOBS=2
#
# %environment
#
EXPOSE 1933 8080  10732 11002 11003 42000

ENV IMAGE=indigo
ENV CC=gcc-14
ENV CXX=g++-14
ENV CUDAHOSTCXX=g++-14
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib:${CUDA_HOME}/lib64"
ENV LLAMA_ARG_CTX_SIZE="${CONTEXT_SIZE}"
ENV LLAMA_ARG_HOST=0.0.0.0
ENV LLAMA_ARG_N_PARALLEL=2
ENV MODEL_DIRECTORY="${MODEL_DIRECTORY}"
ENV OPENVIKING_CONFIG_FILE="${HOME}/.openviking/ov.conf"
# openviking-server refuses dev auth mode on a non-loopback host, so the
# container default is loopback; OPENVIKING_URL already uses 127.0.0.1.
ENV OPENVIKING_SERVER_HOST=127.0.0.1
ENV OPENVIKING_SERVER_PORT=1933
ENV MCP_FILESYSTEM_PORT=11002
ENV MCP_FILESYSTEM_WORKSPACE="${HOME}/dev"
ENV MCP_RUST_ANALYZER_PORT=11003
ENV RUST_ANALYZER_WORKSPACE="${HOME}/dev"
ENV PINOKIO_HOME="${HOME}/.pinokio"
ENV PINOKIO_DOMAIN=pinokio.localhost
ENV PINOKIO_HTTPS_ACTIVE=1
ENV PINOKIO_NETWORK_ACTIVE=1
ENV PINOKIO_SYSTEM_CADDY=1
ENV INDIGO_ENABLE_INFERENCE=1
ENV INDIGO_ENABLE_FILESYSTEM=0
ENV INDIGO_ENABLE_RUST_ANALYZER=0
ENV INDIGO_ENABLE_OPENVIKING=0
ENV INDIGO_ENABLE_PINOKIO=0
ENV CARGO_HOME="${HOME}/.cargo"
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH="/usr/local/cargo/bin:/opt/mcp/node/bin:/opt/openviking/bin:/opt/pinokio/bin:/opt/pinokio/node/bin:${PATH}"
# Keep inference compilation ahead of service and configuration copies so a
# routine service-only edit can reuse this expensive layer.
COPY --chmod=0755 ./scripts/build_llama_cpp_from_source.sh /tmp/build_llama_cpp_from_source.sh
#
# Inference build
#
USER root
RUN if [ "${INDIGO_LLAMA_BACKEND}" = cuda ]; then install_cuda_toolkit; \
    elif [ "${INDIGO_LLAMA_BACKEND}" != cpu ]; then echo "unsupported llama backend: ${INDIGO_LLAMA_BACKEND}" >&2; exit 1; fi \
    && install -d -m 0755 -o "${USER_NAME}" -g "${USER_NAME}" "${MODEL_DIRECTORY}" "${HOME}/.config/llama-swap"
RUN sed -i 's/\r$//' /tmp/build_llama_cpp_from_source.sh \
    && LLAMA_CPP_COMMIT="${LLAMA_CPP_COMMIT}" \
        INDIGO_LLAMA_BACKEND="${INDIGO_LLAMA_BACKEND}" \
        INDIGO_LLAMA_BUILD_JOBS="${INDIGO_LLAMA_BUILD_JOBS}" \
        bash /tmp/build_llama_cpp_from_source.sh \
    && rm -f /tmp/build_llama_cpp_from_source.sh
#
# %files
#
COPY --from=pinokio-source --chown=${USER_NAME}:${USER_NAME} /src /opt/pinokio/app
COPY --from=pinokio-build --chown=${USER_NAME}:${USER_NAME} /app/node_modules /opt/pinokio/app/node_modules
COPY --from=pinokio-build /usr/local /opt/pinokio/node
COPY --from=pinokio-caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=mcp-node /usr/local /opt/mcp/node
COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup
#
# Post
#
USER root
RUN ln -s /usr/local/cargo/bin/cargo /usr/local/bin/cargo \
    && ln -s /usr/local/cargo/bin/rust-analyzer /usr/local/bin/rust-analyzer \
    && ln -s /usr/local/cargo/bin/rust-analyzer-mcp /usr/local/bin/rust-analyzer-mcp \
    && ln -s /usr/local/cargo/bin/rustc /usr/local/bin/rustc \
    && ln -s /usr/local/cargo/bin/rustfmt /usr/local/bin/rustfmt \
    && ln -s /usr/local/cargo/bin/rustup /usr/local/bin/rustup
RUN install -d -m 0755 -o "${USER_NAME}" -g "${USER_NAME}" "${HOME}/.openviking" "${HOME}/.pinokio" \
    "${CARGO_HOME}" \
    && install -d -m 0755 /etc/indigo/defaults \
    && chmod 0755 /etc/indigo
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bluez \
        curl \
        git \
        lsof \
        net-tools \
        openssh-client \
        p7zip-full \
        pv \
    && rm -rf /var/lib/apt/lists/* \
    && /usr/bin/python3 -m venv /opt/openviking \
    && /opt/openviking/bin/pip install --no-cache-dir "openviking==${OPENVIKING_VERSION}"
USER "${USER_NAME}"
RUN eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
    && brew tap mostlygeek/llama-swap \
    && brew trust mostlygeek/llama-swap \
    && brew install --force hf llama-swap \
    && actual_hf_version="$(brew list --versions hf | awk '{ print $2 }')" \
    && actual_llama_swap_version="$(brew list --versions llama-swap | awk '{ print $2 }')" \
    && if [ "${actual_hf_version}" != "${HF_VERSION}" ]; then \
        echo "hf version mismatch: expected ${HF_VERSION}, installed ${actual_hf_version}" >&2; \
        exit 1; \
    fi \
    && if [ "${actual_llama_swap_version}" != "${LLAMA_SWAP_VERSION}" ]; then \
        echo "llama-swap version mismatch: expected ${LLAMA_SWAP_VERSION}, installed ${actual_llama_swap_version}" >&2; \
        exit 1; \
    fi
# Runtime-only tuning defaults stay after dependency installation so changing
# them cannot invalidate inference compilation or package layers.
ENV LLAMA_ARG_BATCH=2048
ENV LLAMA_ARG_UBATCH=2048
USER root
# Replace the inherited bundle as a unit: its Node executable and native
# modules must all match the target architecture.
COPY --from=code-server --chown=${USER_NAME}:${USER_NAME} /usr/lib/code-server /app/code-server
# Seed Docker-managed volumes with writable ownership before they are mounted.
RUN install -d -m 0755 -o "${USER_NAME}" -g "${USER_NAME}" \
    "${HOME}/.codex" "${HOME}/.config/opencode" "${HOME}/.local/share/opencode"
# Frequently edited runtime files stay after dependency installation so their
# changes invalidate only the final normalization and cleanup layers.
COPY --chmod=0755 --chown=${USER_NAME}:${USER_NAME} ./rootfs/etc/services.d/ /etc/services.d/
COPY --chmod=0755 --chown=${USER_NAME}:${USER_NAME} ./rootfs/etc/cont-init.d/* /etc/cont-init.d/
COPY --chmod=0755 ./rootfs/opt/pinokio/bin/conda /opt/pinokio/bin/conda
COPY --chmod=0644 ./config/llama-swap/config.yaml /etc/indigo/defaults/llama-swap.yaml
COPY --chmod=0644 ./config/llama-swap/mlx.yaml /etc/indigo/defaults/llama-swap-mlx.yaml
COPY --chmod=0644 ./config/agents/opencode.json /etc/indigo/defaults/opencode.json
COPY --chmod=0644 ./config/agents/opencode.mlx.json /etc/indigo/defaults/opencode-mlx.json
COPY --chmod=0644 ./config/agents/codex.toml /etc/indigo/defaults/codex.toml
COPY --chmod=0755 ./scripts/healthcheck.sh /healthcheck
RUN find /etc/services.d /etc/cont-init.d -type f -exec sed -i 's/\r$//' {} + \
    && sed -i 's/\r$//' /healthcheck /opt/pinokio/bin/conda
RUN cleanup \
    && chmod 0755 /etc/indigo /etc/indigo/defaults
#
# %runscript
#
USER "${USER_NAME}"
WORKDIR "${HOME}/dev"
SHELL ["/bin/bash", "-c"]
HEALTHCHECK --interval=5m --timeout=30s --start-period=10s --retries=3 \
    CMD ["/healthcheck"]
ENTRYPOINT ["/init"]
CMD ["/bin/zsh"]
