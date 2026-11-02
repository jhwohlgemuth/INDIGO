#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator="${repository_root}/scripts/new.sh"
checker="${repository_root}/scripts/check.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/indigo-new-instance.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT

workspace="${fixture}/workspace"
mkdir -p "${workspace}/scripts"
cp "${repository_root}/.env" "${workspace}/base.env"
ln -s "${checker}" "${workspace}/scripts/check.sh"

run_generator() {
    (
        cd "${workspace}"
        BASE_ENV_FILE=base.env "${generator}" "$@"
    )
}

expect_failure() {
    local expected="$1"
    local status
    shift
    set +e
    run_generator "$@" > "${fixture}/out" 2> "${fixture}/err"
    status=$?
    set -e
    if [[ ${status} -eq 0 ]]; then
        echo "expected instance generation to fail: $*" >&2
        exit 1
    fi
    grep -Fq "${expected}" "${fixture}/err"
}

# The default offset is deliberately separated from every base port.
run_generator default > "${fixture}/default.out"
grep -Fq "wrote .env.default" "${fixture}/default.out"
grep -Fqx 'INFERENCE_PUBLISHED_PORT=11732' "${workspace}/.env.default"
"${checker}" "${workspace}/.env.default" > /dev/null

# A deliberately separated offset produces a valid instance environment.
run_generator safe 2000 > "${fixture}/safe.out"
grep -Fq "wrote .env.safe" "${fixture}/safe.out"
grep -Fqx 'INFERENCE_PUBLISHED_PORT=12732' "${workspace}/.env.safe"
"${checker}" "${workspace}/.env.safe" > /dev/null

# Offsets use one canonical spelling.
expect_failure "offset must be a canonical integer with no leading zeros" leading 01000
[[ ! -e "${workspace}/.env.leading" ]]

# More than the documented name and offset operands is an error.
expect_failure "expected a name and optional offset" extra 1000 unexpected
[[ ! -e "${workspace}/.env.extra" ]]

# A listening-port diagnostic remains a warning and does not block output.
fake_bin="${fixture}/fake-bin"
mkdir -p "${fake_bin}"
cat > "${fake_bin}/lsof" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 0755 "${fake_bin}/lsof"
(
    cd "${workspace}"
    PATH="${fake_bin}:${PATH}" BASE_ENV_FILE=base.env \
        "${generator}" busy 2000 > "${fixture}/busy.out" 2> "${fixture}/busy.err"
)
grep -Fq "is already in use on this host" "${fixture}/busy.err"
grep -Fq "note: some ports are already in use" "${fixture}/busy.err"
[[ -f "${workspace}/.env.busy" ]]

# Generation also succeeds when lsof is unavailable.
no_lsof_bin="${fixture}/no-lsof-bin"
mkdir -p "${no_lsof_bin}"
for command_name in bash awk grep mktemp mv rm; do
    ln -s "$(command -v "${command_name}")" "${no_lsof_bin}/${command_name}"
done
(
    cd "${workspace}"
    PATH="${no_lsof_bin}" BASE_ENV_FILE=base.env \
        "${generator}" no-lsof 3000 > "${fixture}/no-lsof.out" 2> "${fixture}/no-lsof.err"
)
[[ -f "${workspace}/.env.no-lsof" ]]
[[ ! -s "${fixture}/no-lsof.err" ]]

# A failed final validation never replaces an existing target, even with force.
rm "${workspace}/scripts/check.sh"
cat > "${workspace}/scripts/check.sh" << EOF
#!/usr/bin/env bash
if [[ "\$1" == *.tmp.* ]]; then
    echo "forced generated-file validation failure" >&2
    exit 1
fi
exec "${checker}" "\$@"
EOF
chmod 0755 "${workspace}/scripts/check.sh"
printf '%s\n' 'preserve this file' > "${workspace}/.env.retained"
expect_failure "the existing file was not changed" retained 4000 --force
grep -Fqx 'preserve this file' "${workspace}/.env.retained"
if compgen -G "${workspace}/.env.retained.tmp.*" > /dev/null; then
    echo "temporary instance file was not cleaned up" >&2
    exit 1
fi

echo 'new instance generation contract passed'
