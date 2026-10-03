#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly repository_root
test_root=$(mktemp -d)
readonly test_root
trap 'rm -rf "$test_root"' EXIT

mkdir -p \
    "$test_root/bin" \
    "$test_root/source/walter/boot-config" \
    "$test_root/source/walter/appdata" \
    "$test_root/source/kermit" \
    "$test_root/repositories" \
    "$test_root/state"
touch "$test_root/source/kermit/config.xml"

cat >"$test_root/bin/restic" <<'EOF'
#!/bin/sh
echo "$RESTIC_REPOSITORY $*" >>"$RESTIC_TEST_LOG"
if [ "${RESTIC_FAIL_COMMAND:-}" = "${1:-}" ]; then
    exit 1
fi
exit 0
EOF
cat >"$test_root/bin/wget" <<'EOF'
#!/bin/sh
echo "$*" >>"$WGET_TEST_LOG"
EOF
chmod +x "$test_root/bin/restic" "$test_root/bin/wget"

export PATH="$test_root/bin:$PATH"
export BACKUP_STATE_DIRECTORY="$test_root/state"
export BACKUP_SOURCE_DIRECTORY="$test_root/source"
export BACKUP_REPOSITORY_DIRECTORY="$test_root/repositories"
export KERMIT_WAIT_SECONDS=0
export RESTIC_PASSWORD_WALTER=walter-test-password
export RESTIC_PASSWORD_KERMIT=kermit-test-password
export HEALTHCHECK_SUCCESS_URL_WALTER=https://health.invalid/walter/success
export HEALTHCHECK_FAILURE_URL_WALTER=https://health.invalid/walter/failure
export HEALTHCHECK_SUCCESS_URL_KERMIT=https://health.invalid/kermit/success
export HEALTHCHECK_FAILURE_URL_KERMIT=https://health.invalid/kermit/failure
export RESTIC_TEST_LOG="$test_root/restic.log"
export WGET_TEST_LOG="$test_root/wget.log"

"$repository_root/muppets/walter/backup/run.sh" run-now

grep -F -- '--keep-daily 7 --keep-weekly 4 --prune' "$RESTIC_TEST_LOG" >/dev/null
grep -F 'health.invalid/walter/success' "$WGET_TEST_LOG" >/dev/null
grep -F 'health.invalid/kermit/success' "$WGET_TEST_LOG" >/dev/null

: >"$WGET_TEST_LOG"
export RESTIC_FAIL_COMMAND=backup
if "$repository_root/muppets/walter/backup/run.sh" run-now; then
    echo "Expected a failed Restic backup to fail the job." >&2
    exit 1
fi
grep -F 'health.invalid/walter/failure' "$WGET_TEST_LOG" >/dev/null
grep -F 'health.invalid/kermit/failure' "$WGET_TEST_LOG" >/dev/null
unset RESTIC_FAIL_COMMAND

touch -d '2 hours ago' "$test_root/source/kermit/config.xml"
: >"$WGET_TEST_LOG"
if "$repository_root/muppets/walter/backup/run.sh" run-now; then
    echo "Expected a stale Kermit export to fail the job." >&2
    exit 1
fi
grep -F 'health.invalid/kermit/failure' "$WGET_TEST_LOG" >/dev/null

echo "Backup scheduler tests passed."
