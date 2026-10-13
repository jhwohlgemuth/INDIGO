# Indigo — Isolated Native Development Instance for Generative Operations

> A local workshop for agentic software development — local-first, agents-first. Indigo = **I**solated **N**ative **D**evelopment **I**nstance for **G**enerative **O**perations.

Indigo is a GPU-enabled environment for local models, coding agents, formal
verification, and research. OpenCode is the primary client and is preconfigured
for Indigo's OpenAI-compatible `llama-swap` endpoint. Codex remains supported
through a generated MCP configuration.

The Indigo container runs persistent OpenViking, Pinokio, Filesystem MCP,
and Rust Analyzer MCP processes under s6 alongside inference.

| Service | Purpose | Host endpoint |
| --- | --- | --- |
| Indigo inference | Local OpenAI-compatible models | `http://127.0.0.1:10732/v1` |
| OpenViking | Context database, Studio, and MCP | `http://127.0.0.1:1933` |
| Pinokio | Management interface | `http://127.0.0.1:42000` |
| Pinokio proxy | Stable ingress for dynamic web apps | `http://127.0.0.1:42080` |
| Filesystem MCP | Workspace-scoped file operations | `http://127.0.0.1:11002/mcp` |
| Rust Analyzer MCP | Workspace diagnostics, navigation, and refactoring | `http://127.0.0.1:11003/mcp` |

> Lean formal verification has moved to [`jhwohlgemuth/gold`](https://github.com/jhwohlgemuth/gold) as a standalone `mcp-lean` service (`--profile formal`).

All published ports bind to `127.0.0.1` by default. Every host port and the
bind address are configurable with Compose environment variables.

## Quick start

Run the published image with a single copy-pasteable command; no repository,
Compose file, environment file, or build step is required. This is exactly what
`make run` expands to from the committed `.env`, with the values inlined. State
lives in named volumes prefixed with the container name:

```shell
docker run -d -i -t --name indigo --hostname indigo --gpus all --restart unless-stopped --shm-size 2gb -p 10732:10732 -p 1337:1337 -p 4873:4873 -p 13337:13337 --volume indigo-models:/home/nonroot/.models --volume indigo-opencode-config:/home/nonroot/.config/opencode --volume indigo-opencode-data:/home/nonroot/.local/share/opencode ghcr.io/jhwohlgemuth/indigo:0.1.4
```

To tear it down:

```shell
docker stop indigo
docker rm indigo
```

If you have this repository, `make run` renders a similar command from `.env`
instead of hardcoding it, so published ports, mounted volumes, the image tag,
and the publish address stay configurable:

```shell
make run
make run ENV_FILE=.env.two
make stop
make rm
```

To try the image with nothing configured at all, `make start` runs it with no
published ports, no volumes, and no `.env` edits. The image's own defaults
apply and the services are reachable inside the container only, which is enough
to attach a shell or exercise the image:

```shell
make start
docker attach indigo
make stop
```

The same container can be started with host bind mounts instead of named
volumes, which keeps the workspace, models, OpenViking state, and Pinokio
installations directly accessible from the host. Create any missing host
directories first.

Windows PowerShell:

```powershell
docker run --detach --gpus all --name indigo --hostname indigo --restart unless-stopped --shm-size 2g -p 10732:10732 -p 127.0.0.1:1337:1337 -p 1933:1933 -p 42000:42000 -p 42080:8080 -p 11002:11002 -p 11003:11003 --volume "${HOME}\dev:/home/nonroot/dev" --volume "${HOME}\.models:/home/nonroot/.models" ghcr.io/jhwohlgemuth/indigo:0.1.4
```

Linux or macOS:

```shell
docker run --detach --gpus all --name indigo --hostname indigo --restart unless-stopped --shm-size 2g -p 10732:10732 -p 127.0.0.1:1337:1337 -p 1933:1933 -p 42000:42000 -p 42080:8080 -p 11002:11002 -p 11003:11003 --volume "$HOME/dev:/home/nonroot/dev" --volume "$HOME/.models:/home/nonroot/.models" ghcr.io/jhwohlgemuth/indigo:0.1.4
```

Create any missing host directories before running the command.

Equivalent Make shortcuts are available for routine stack operations:

```shell
make compose-build
make up
make ps
make logs
make restart
make down
```

Each MCP server also has a one-word target:

```shell
make filesystem
make rust
```

The `filesystem` and `rust` targets build and start Indigo because both MCPs
are s6 services in that container.

`COMPOSE` and `COMPOSE_ARGS` are overridable.

## Compose

Compose is the build-from-source path. It builds the image locally, seeds the
agent configuration, and keeps state in Docker-managed volumes:

```shell
docker compose up --build --detach
docker compose ps
```

`.env` is the single source of truth for both Compose and `make run`. It holds
the image tag, the instance identity, and every published host port, so a port
change is a one-line edit there. `compose.yaml` declares those variables with
`${VAR:?}` and the Makefile defines no fallbacks, so a missing value fails
immediately instead of rendering an empty image reference or port.

Optional behavior knobs (`INDIGO_DEFAULT_MODEL`, `RUST_ANALYZER_WORKSPACE`,
`LLAMA_ARG_CTX_SIZE`, `OPENVIKING_WITH_BOT`, `OPENVIKING_CONF_CONTENT`, and the
like) still fall back to the defaults in `compose.yaml` and the image; they are
listed as comments at the bottom of `.env`.

Validate the file after editing it:

```shell
make check-env
make check-env ENV_FILE=.env.two
```

## Multiple instances

`scripts/new.sh` copies `.env` into a per-instance file with every
published port incremented, its own Compose project name, its own hostname, and
its own Pinokio domain. Named volumes are namespaced by project name, so
instances do not share state:

```shell
scripts/new.sh two            # writes .env.two with +1 on every port
scripts/new.sh three 1000     # writes .env.three with +1000
```

`make instance NAME=two` is an equivalent shortcut. Start an instance by
selecting its environment file:

```shell
make up ENV_FILE=.env.two
make logs ENV_FILE=.env.two
make down ENV_FILE=.env.two
```

Equivalent by hand:

```shell
docker compose --env-file .env.two -p indigo-two up --detach
```

`COMPOSE_PROJECT_NAME` and `INDIGO_HOSTNAME` in the generated file also drive the
raw `docker run` path, so `make run ENV_FILE=.env.two` creates a container named
`indigo-two` with its own volumes and published ports. Instance files are
ignored by git; regenerate them at any time, or pass `BASE_ENV_FILE=.env.two` to
derive one instance from another. Both generators validate their input and
output with `scripts/check.sh`, so a malformed base file or a port collision
aborts before anything is written.

Before submitting changes, normalize text files, format shell scripts, and run
the repository checks with:

```shell
make prepare
```

`prepare` runs `make format` first; the format target uses `dos2unix` for shell,
ShellCheck, Compose, workflow, and configuration YAML files, then applies
`shfmt` to shell scripts. `make check` runs `shfmt --diff`, ShellCheck, and
`scripts/check.sh` against `.env` or the selected `ENV_FILE`, so a broken
environment fails before an image build starts.

OpenViking waits for a valid configuration on first use. Initialize it,
validate the selected local or remote embedding/VLM providers, and restart:

```shell
docker compose exec indigo openviking-server init
docker compose exec indigo openviking-server doctor
```

The waiting service logs the missing configuration once at startup and then
stays silent until `ov.conf` exists; it logs a single line when the file
appears and the server starts. The Makefile shortcut is `make exec CMD="openviking-server init"`.

If the server rejects a configuration it exits, and s6 would restart it several
times a second, repeating the same error forever. The service therefore retries
on a bounded interval instead, reporting the failure once per attempt, and
retries immediately when `ov.conf` changes. Set `OPENVIKING_RETRY_INTERVAL` to
change the interval (default `300` seconds).

OpenViking binds `127.0.0.1` by default because `openviking-server` refuses
`dev` auth mode on a non-loopback host. Set `OPENVIKING_SERVER_HOST` and
`server.auth_mode` together if you need a different binding; `api_key` auth with
a configured `server.root_api_key` is required before binding beyond loopback.

`OPENVIKING_WITH_BOT=1` adds the optional bot endpoint. It is off by default,
and the flag is only passed when enabled, so the server never starts with an
argument its CLI does not accept.

For a local provider, the inference endpoint visible from OpenViking is
`http://127.0.0.1:10732/v1`. The chosen model must provide the capability
OpenViking requests; the default coding model is not assumed to be an embedding
or vision model.

The container healthcheck covers inference, the notebook services, Filesystem
MCP, Rust Analyzer MCP, OpenViking, the Pinokio management UI, and Pinokio's
Caddy ingress. Before OpenViking has an `ov.conf`, its health result is reported
as `WAIT` and does not make the container unhealthy. Once the file exists,
`http://127.0.0.1:1933/health` must succeed. The remaining checks are required.

OpenCode inside Indigo receives a default config only if
`~/.config/opencode/opencode.json` does not exist. Codex follows the same rule
for `~/.codex/config.toml`.

## Host configuration

Host setup is deliberately external to the container. The planned workflow is:

1. Use
   [`jhwohlgemuth/my-shell-setup`](https://github.com/jhwohlgemuth/my-shell-setup)
   to install and maintain host commands, shell integration, and base OpenCode
   and Codex configuration.
2. Start Indigo so its inference and MCP endpoints are available on the
   configured loopback ports.
3. Set ACORN's OpenCode sync target to Indigo in the ACORN configuration:

   ```yaml
   config:
     opencode:
       baseUrl: http://127.0.0.1:10732/v1
       providerId: indigo
       providerName: Indigo local models
   ```

4. Preview and apply ACORN's model-derived OpenCode configuration:

   ```shell
   acorn sync --opencode --dry-run
   acorn sync --opencode
   ```

`acorn sync` is authoritative for the host's available local models and
OpenCode provider/model entries. It preserves unrelated client settings. The
shell-setup repository owns installing the clients and distributing their base
configuration, including MCP endpoints; ACORN does not currently synchronize
Codex. Indigo does not overwrite host dotfiles.

[`config/agents/opencode.host.json`](config/agents/opencode.host.json) and
[`config/agents/codex.host.toml`](config/agents/codex.host.toml) are canonical
Indigo MCP templates intended for consumption by `my-shell-setup`, not an
independent manual host-install mechanism. The OpenCode template intentionally
contains no model inventory because ACORN supplies it.

## Pinokio reverse proxy

Pinokio and OpenViking are installed in the main image and supervised by
`/etc/services.d/pinokio` and `/etc/services.d/openviking`. Pinokio manages a
Caddy 2.9.1 process that automatically tracks web applications launched on
dynamic internal ports. Indigo selects the custom-domain router with
`PINOKIO_DOMAIN=pinokio.localhost` and publishes fixed port `8080` as host port
`42080`.

Applications are reached using hostnames generated by Pinokio, normally in the
form `<app>-pinokio.localhost:42080`. The management UI remains on port `42000`.
For access from other machines, set `PINOKIO_DOMAIN` to a domain whose wildcard
DNS points at the Docker host.

The proxy removes per-app publishing for HTTP, HTTPS, and WebSocket apps.
Indigo does not publish a dynamic raw TCP/UDP port range; Pinokio apps must
use the managed web proxy or add an explicit, narrowly scoped port mapping to
`compose.yaml` when a non-HTTP protocol genuinely requires one.

## External access and security

Set `INDIGO_PUBLISH_HOST=0.0.0.0` to accept connections through any host
interface. Do this only on a trusted network or behind an authenticated,
TLS-terminating gateway: most MCP services have no inbound authentication and
the filesystem MCP can modify the shared workspace.

Common port overrides, edited in `.env` and validated with `make check-env`:

```dotenv
INDIGO_PUBLISH_HOST=127.0.0.1
INFERENCE_PUBLISHED_PORT=10732
OPENVIKING_PUBLISHED_PORT=1933
PINOKIO_PUBLISHED_PORT=42000
PINOKIO_PROXY_PUBLISHED_PORT=42080
MCP_FILESYSTEM_PUBLISHED_PORT=11002
MCP_RUST_ANALYZER_PUBLISHED_PORT=11003
```

The Rust Analyzer MCP starts against `/home/nonroot/dev` by default. Set
`RUST_ANALYZER_WORKSPACE` to a Rust project path inside the shared workspace
when its `Cargo.toml` is below that root, for example
`RUST_ANALYZER_WORKSPACE=/home/nonroot/dev/my-rust-project`.

Optional upstream credentials are passed at runtime and never baked into the
images through `OPENVIKING_CONF_CONTENT`.

## Persistent data

Compose volumes retain the workspace, models, OpenCode state, Codex state,
OpenViking data at `~/.openviking`, Pinokio installations at `~/.pinokio`,
and Cargo cache for Rust Analyzer. Indigo expects models beneath
`/home/nonroot/.models`; ACORN remains responsible for model acquisition and
generated `llama-swap` entries.
