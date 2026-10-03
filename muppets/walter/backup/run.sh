#!/bin/sh
set -eu

readonly state_directory="${BACKUP_STATE_DIRECTORY:-/state}"
readonly source_directory="${BACKUP_SOURCE_DIRECTORY:-/source}"
readonly repository_directory="${BACKUP_REPOSITORY_DIRECTORY:-/repositories}"
readonly marker_file="${state_directory}/last-run"
mkdir -p "$state_directory"

notify() {
    url=$1
    [ -z "$url" ] || wget --quiet --output-document=/dev/null "$url"
}

run_restic() {
    host=$1
    password=$2
    shift 2
    export RESTIC_REPOSITORY="$repository_directory/$host"
    export RESTIC_PASSWORD="$password"

    if ! restic snapshots >/dev/null 2>&1; then
        restic init
    fi
    restic backup "$@" --host "$host" --tag nightly || return
    restic forget --host "$host" --keep-daily 7 --keep-weekly 4 --prune || return
    if [ "$(date +%u)" = 7 ]; then
        restic check || return
    fi
}

run_walter() {
    if run_restic walter "$RESTIC_PASSWORD_WALTER" \
        "$source_directory/walter/boot-config" "$source_directory/walter/appdata" \
        --exclude="$source_directory/walter/appdata/homelab-backup" \
        --exclude="$source_directory/walter/appdata/backup" \
        --exclude='**/cache/**' --exclude='**/Cache/**' --exclude='**/logs/**'; then
        notify "$HEALTHCHECK_SUCCESS_URL_WALTER"
    else
        notify "$HEALTHCHECK_FAILURE_URL_WALTER" || true
        return 1
    fi
}

run_kermit() {
    deadline=$(($(date +%s) + ${KERMIT_WAIT_SECONDS:-600}))
    newest=""
    while [ -z "$newest" ]; do
        newest=$(find "$source_directory/kermit" -type f -name '*.xml' -mmin -30 -print -quit)
        if [ -n "$newest" ] || [ "$(date +%s)" -ge "$deadline" ]; then
            break
        fi
        sleep 20
    done
    if [ -z "$newest" ]; then
        echo "No Kermit configuration export newer than 30 minutes." >&2
        notify "$HEALTHCHECK_FAILURE_URL_KERMIT" || true
        return 1
    fi
    if run_restic kermit "$RESTIC_PASSWORD_KERMIT" "$source_directory/kermit"; then
        notify "$HEALTHCHECK_SUCCESS_URL_KERMIT"
    else
        notify "$HEALTHCHECK_FAILURE_URL_KERMIT" || true
        return 1
    fi
}

run_all() {
    if ! mkdir "$state_directory/run.lock" 2>/dev/null; then
        echo "Another backup run is already active; skipping." >&2
        return 0
    fi
    trap 'rmdir "$state_directory/run.lock" 2>/dev/null || true' EXIT INT TERM
    status=0
    run_walter || status=1
    run_kermit || status=1
    rmdir "$state_directory/run.lock"
    return "$status"
}

case "${1:-}" in
    run-now)
        run_all
        exit
        ;;
    snapshots)
        case "${2:-}" in
            walter)
                export RESTIC_REPOSITORY="$repository_directory/walter"
                export RESTIC_PASSWORD="$RESTIC_PASSWORD_WALTER"
                ;;
            kermit)
                export RESTIC_REPOSITORY="$repository_directory/kermit"
                export RESTIC_PASSWORD="$RESTIC_PASSWORD_KERMIT"
                ;;
            *)
                echo "Usage: $0 snapshots {walter|kermit}" >&2
                exit 2
                ;;
        esac
        restic snapshots
        exit
        ;;
esac

while :; do
    today=$(date +%F)
    current_time=$(date +%H:%M)
    last_run=$(cat "$marker_file" 2>/dev/null || true)
    if [ "$current_time" = 03:00 ] && [ "$last_run" != "$today" ]; then
        echo "$today" >"$marker_file"
        run_all || true
    fi
    sleep 20
done
