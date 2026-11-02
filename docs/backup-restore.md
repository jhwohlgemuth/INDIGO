# Backup and restore standalone state

This procedure applies to the fully persistent `make run` mode. It snapshots a
stopped instance and restores it under a different container name so the source
volumes are never overwritten.

Back up these seven instance-named volumes:

| Volume suffix | Container path | Contents |
| --- | --- | --- |
| `workspace` | `/home/nonroot/dev` | Workspace files |
| `llama-swap-config` | `/home/nonroot/.config/llama-swap` | Router configuration |
| `opencode-config` | `/home/nonroot/.config/opencode` | OpenCode configuration |
| `opencode-data` | `/home/nonroot/.local/share/opencode` | OpenCode state |
| `codex` | `/home/nonroot/.codex` | Codex configuration and credentials |
| `openviking` | `/home/nonroot/.openviking` | OpenViking state |
| `pinokio` | `/home/nonroot/.pinokio` | Pinokio state |

The `<instance>-models` and `<instance>-cargo-cache` volumes are excluded by
default because models can be downloaded again and Cargo data is a cache. Copy
them separately only when the additional archive size is intentional.

## Protect the backup

The archives can contain API keys and other credentials. Store them outside the
repository on trusted local or encrypted storage. The commands below create a
mode `0700` directory and mode `0600` files; do not commit, share, or upload the
directory without encrypting it first.

Choose explicit source and backup paths. The source container must still exist
so Docker can identify the exact image used to read and restore its volumes. Run
all command blocks below in the same Bash or Zsh session so these variables and
arrays remain available.

```shell
SOURCE=indigo
BACKUP_DIR=/absolute/path/to/secure/backups/indigo-YYYYMMDDTHHMMSSZ
STATE_VOLUMES=(workspace llama-swap-config opencode-config opencode-data codex openviking pinokio)
BACKUP_HELPER="${SOURCE}-backup-helper"

umask 077
install -d -m 0700 "${BACKUP_DIR}"
BACKUP_IMAGE="$(docker inspect --format '{{.Config.Image}}' "${SOURCE}")"
docker stop "${SOURCE}"

if docker container inspect "${BACKUP_HELPER}" >/dev/null 2>&1; then
  echo "backup helper already exists: ${BACKUP_HELPER}" >&2
  exit 1
fi
```

Do not continue if `BACKUP_IMAGE` is empty or the stopped container is not the
intended source.

## Create and verify the snapshot

The temporary helper mounts every source volume read-only. Alongside each
archive, it records file checksums and a sorted type, mode, numeric owner, path,
and symlink target manifest for restore verification. `docker cp` transfers the
verified snapshot to the CLI host, including when Docker uses a remote context.

```shell
backup_mounts=()
for suffix in "${STATE_VOLUMES[@]}"; do
  volume="${SOURCE}-${suffix}"
  docker volume inspect "${volume}" >/dev/null
  backup_mounts+=(--volume "${volume}:/source/${suffix}:ro")
done

docker create --name "${BACKUP_HELPER}" --entrypoint /bin/sleep \
  "${backup_mounts[@]}" "${BACKUP_IMAGE}" infinity >/dev/null
docker start "${BACKUP_HELPER}" >/dev/null
docker exec --user 0 "${BACKUP_HELPER}" install -d -m 0700 /backup

for suffix in "${STATE_VOLUMES[@]}"; do
  docker exec --user 0 "${BACKUP_HELPER}" /bin/bash -lc '
    set -euo pipefail
    cd "/source/${1}"
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum > "/backup/${1}.files.sha256"
    find . -printf "%y %m %U:%G %p -> %l\n" | LC_ALL=C sort > "/backup/${1}.metadata"
    tar --numeric-owner -czf "/backup/${1}.tar.gz" .
  ' -- "${suffix}"
done

docker exec --user 0 "${BACKUP_HELPER}" /bin/bash -lc '
    set -euo pipefail
    cd /backup
    sha256sum -- *.tar.gz *.files.sha256 *.metadata > SHA256SUMS
    sha256sum --check SHA256SUMS
  '
docker cp "${BACKUP_HELPER}:/backup/." "${BACKUP_DIR}/"
docker rm -f -- "${BACKUP_HELPER}" >/dev/null
chmod 0600 "${BACKUP_DIR}"/*
```

Keep the source stopped until the snapshot is verified. Restart it only if no
restore is needed: `docker start "${SOURCE}"`.

## Restore into a different instance

Use a new target name. The preflight fails instead of reusing a container or
volume, which protects existing state.

```shell
TARGET=indigo-restored
RESTORE_HELPER="${TARGET}-restore-helper"

for container in "${TARGET}" "${RESTORE_HELPER}"; do
  if docker container inspect "${container}" >/dev/null 2>&1; then
    echo "target container already exists: ${container}" >&2
    exit 1
  fi
done
for suffix in "${STATE_VOLUMES[@]}" models cargo-cache; do
  if docker volume inspect "${TARGET}-${suffix}" >/dev/null 2>&1; then
    echo "target volume already exists: ${TARGET}-${suffix}" >&2
    exit 1
  fi
done

restore_mounts=()
for suffix in "${STATE_VOLUMES[@]}"; do
  volume="${TARGET}-${suffix}"
  docker volume create "${volume}" >/dev/null
  restore_mounts+=(--volume "${volume}:/restore/${suffix}")
done

docker create --name "${RESTORE_HELPER}" --entrypoint /bin/sleep \
  "${restore_mounts[@]}" "${BACKUP_IMAGE}" infinity >/dev/null
docker start "${RESTORE_HELPER}" >/dev/null
docker exec --user 0 "${RESTORE_HELPER}" install -d -m 0700 /backup
docker cp "${BACKUP_DIR}/." "${RESTORE_HELPER}:/backup/"
docker exec --user 0 "${RESTORE_HELPER}" \
  /bin/bash -lc 'cd /backup && sha256sum --check SHA256SUMS'

for suffix in "${STATE_VOLUMES[@]}"; do
  docker exec --user 0 "${RESTORE_HELPER}" /bin/bash -lc '
    set -euo pipefail
    tar --numeric-owner --same-owner --same-permissions \
      -C "/restore/${1}" -xzf "/backup/${1}.tar.gz"
    cd "/restore/${1}"
    sha256sum --check "/backup/${1}.files.sha256"
    find . -printf "%y %m %U:%G %p -> %l\n" | LC_ALL=C sort > /tmp/restored.metadata
    diff -u "/backup/${1}.metadata" /tmp/restored.metadata
  ' -- "${suffix}"
done
docker rm -f -- "${RESTORE_HELPER}" >/dev/null
```

The checksum and metadata comparisons verify recovered content, ownership, and
permissions, including mode `0600` credential files. Start the restored instance
with the same image. `make run` creates fresh model and Cargo-cache volumes:

```shell
make run CONTAINER="${TARGET}" IMAGE_REF="${BACKUP_IMAGE}"
```

Confirm the workspace and router configuration before using the restored
instance for real work. Keep the source volumes until that check is complete.

## Roll back a failed restore

Stop before cleanup and verify that `TARGET` is the new disposable name, never
the source. Remove only the target container and its nine target volumes:

```shell
docker rm -f -- "${BACKUP_HELPER}" "${RESTORE_HELPER}" "${TARGET}" 2>/dev/null || true
for suffix in "${STATE_VOLUMES[@]}" models cargo-cache; do
  docker volume rm -- "${TARGET}-${suffix}" 2>/dev/null || true
done
```

Rollback does not modify the source container, source volumes, or backup. If a
restore check fails, keep the source stopped or restart it and investigate the
failed target separately.
