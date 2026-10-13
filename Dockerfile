ARG NOTEBOOK_VERSION=1.0.4
ARG PINOKIO_NODE_VERSION=20
ARG PINOKIO_COMMIT=2c39f9fe9c40c985e03b13ab8a48ead908139b39
ARG MCP_NODE_VERSION=24

FROM node:${PINOKIO_NODE_VERSION} AS pinokio-source
ARG PINOKIO_COMMIT
ADD https://github.com/pinokiocomputer/pinokiod/archive/${PINOKIO_COMMIT}.tar.gz /tmp/pinokio.tar.gz
RUN mkdir /src \
    && tar -xzf /tmp/pinokio.tar.gz --strip-components=1 -C /src \
    && rm /tmp/pinokio.tar.gz \
    && sed -i '/  async installed() {/a\    if (process.env.PINOKIO_SYSTEM_CADDY === "1") return true' \
        /src/kernel/bin/caddy.js

FROM node:${PINOKIO_NODE_VERSION} AS pinokio-build
WORKDIR /app
RUN apt-get update \
    && apt-get install --yes --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
COPY --from=pinokio-source /src/package.json /src/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM caddy:2.9.1 AS pinokio-caddy

FROM node:${MCP_NODE_VERSION}-bookworm-slim AS mcp-node
ARG SUPERGATEWAY_VERSION=3.4.3
ARG FILESYSTEM_MCP_VERSION=2026.7.10
RUN npm install --global --omit=dev \
        "supergateway@${SUPERGATEWAY_VERSION}" \
        "@modelcontextprotocol/server-filesystem@${FILESYSTEM_MCP_VERSION}" \
    && npm cache clean --force

FROM rust:1.90-bookworm AS rust-toolchain
ARG RUST_ANALYZER_MCP_VERSION=0.4.0
RUN rustup component add rust-analyzer rust-src \
    && cargo install --locked --version "${RUST_ANALYZER_MCP_VERSION}" rust-analyzer-mcp

FROM ghcr.io/jhwohlgemuth/notebook:${NOTEBOOK_VERSION}
#
# %labels
#
LABEL author="Jason Wohlgemuth"
LABEL org.opencontainers.image.source="https://github.com/jhwohlgemuth/indigo"
LABEL org.opencontainers.image.title="Indigo"
LABEL org.opencontainers.image.description="A local workshop for agentic software development"
LABEL org.opencontainers.image.licenses="MIT"
#
# %arguments
#
ARG USER_NAME=nonroot
ARG HOME="/home/${USER_NAME}"
ARG MODEL_DIRECTORY="${HOME}/.models"
ARG CONTEXT_SIZE=0
ARG PORT=10732
ARG OPENVIKING_VERSION=0.4.17
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
ENV LLAMA_ARG_PORT="${PORT}"
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
ENV CARGO_HOME="${HOME}/.cargo"
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH="/usr/local/cargo/bin:/opt/mcp/node/bin:/opt/openviking/bin:/opt/pinokio/bin:/opt/pinokio/node/bin:${PATH}"
#
# %files
#
COPY --chmod=0755 --chown=${USER_NAME}:${USER_NAME} ./rootfs/etc/services.d/ /etc/services.d/
COPY --chmod=0755 --chown=${USER_NAME}:${USER_NAME} ./rootfs/etc/cont-init.d/* /etc/cont-init.d/
COPY --from=pinokio-source --chown=${USER_NAME}:${USER_NAME} /src /opt/pinokio/app
COPY --from=pinokio-build --chown=${USER_NAME}:${USER_NAME} /app/node_modules /opt/pinokio/app/node_modules
COPY --from=pinokio-build /usr/local /opt/pinokio/node
COPY --from=pinokio-caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=mcp-node /usr/local /opt/mcp/node
COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup
COPY --chmod=0755 ./rootfs/opt/pinokio/bin/conda /opt/pinokio/bin/conda
COPY --chmod=0644 --chown=${USER_NAME}:${USER_NAME} ./config/llama-swap/config.yaml "${HOME}/.config/llama-swap/config.yaml"
COPY --chmod=0644 ./config/agents/opencode.json /etc/indigo/defaults/opencode.json
COPY --chmod=0644 ./config/agents/codex.toml /etc/indigo/defaults/codex.toml
COPY --chmod=0755 ./scripts/healthcheck.sh /healthcheck
COPY --chmod=0755 ./scripts/build_llama_cpp_from_source.sh /tmp/build_llama_cpp_from_source.sh
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
RUN install_cuda_toolkit \
    && install -d -m 0755 -o "${USER_NAME}" -g "${USER_NAME}" "${MODEL_DIRECTORY}" "${HOME}/.config/llama-swap"
RUN sed -i 's/\r$//' /tmp/build_llama_cpp_from_source.sh \
    && bash /tmp/build_llama_cpp_from_source.sh \
    && rm -f /tmp/build_llama_cpp_from_source.sh
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
    && brew install --force hf llama-swap
USER root
RUN find /etc/services.d /etc/cont-init.d -type f -exec sed -i 's/\r$//' {} + \
    && sed -i 's/\r$//' /healthcheck /opt/pinokio/bin/conda
RUN cleanup
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
