ARG NOTEBOOK_VERSION=1.0.4
FROM ghcr.io/jhwohlgemuth/notebook:${NOTEBOOK_VERSION}

LABEL author="Jason Wohlgemuth"
LABEL org.opencontainers.image.source="https://github.com/jhwohlgemuth/goldsmith"
LABEL org.opencontainers.image.title="Goldsmith"
LABEL org.opencontainers.image.description="A local workshop for agentic software development"
LABEL org.opencontainers.image.licenses="MIT"

ARG USER_NAME=nonroot
ARG HOME="/home/${USER_NAME}"
ARG MODEL_DIRECTORY="${HOME}/.models"
ARG CONTEXT_SIZE=0
ARG PORT=10732

EXPOSE 10732

ENV IMAGE=goldsmith
ENV CC=gcc-14
ENV CXX=g++-14
ENV CUDAHOSTCXX=g++-14
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64"
ENV LLAMA_ARG_CTX_SIZE="${CONTEXT_SIZE}"
ENV LLAMA_ARG_HOST=0.0.0.0
ENV LLAMA_ARG_N_PARALLEL=2
ENV LLAMA_ARG_PORT="${PORT}"
ENV MODEL_DIRECTORY="${MODEL_DIRECTORY}"

COPY --chmod=0755 --chown=${USER_NAME}:${USER_NAME} ./rootfs/etc/services.d/inference-router/* /etc/services.d/inference-router/
COPY --chmod=0644 --chown=${USER_NAME}:${USER_NAME} ./config/llama-swap/config.yaml "${HOME}/.config/llama-swap/config.yaml"
COPY --chmod=0755 ./scripts/healthcheck.sh /healthcheck

USER root
RUN install_cuda_toolkit
USER "${USER_NAME}"
RUN mkdir -p "${MODEL_DIRECTORY}" "${HOME}/.config/llama-swap" \
    && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
    && brew tap mostlygeek/llama-swap \
    && brew trust mostlygeek/llama-swap \
    && brew install --force hf llama.cpp llama-swap
USER root
RUN cleanup

USER "${USER_NAME}"
WORKDIR "${HOME}/dev"
SHELL ["/bin/bash", "-c"]
HEALTHCHECK --interval=5m --timeout=30s --start-period=10s --retries=3 \
    CMD ["/healthcheck"]
ENTRYPOINT ["/init"]
CMD ["/bin/zsh"]
