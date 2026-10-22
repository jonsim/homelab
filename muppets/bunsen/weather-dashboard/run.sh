#!/bin/sh

set -eu

readonly output=/output/weather-dashboard.png
readonly staging_directory=/app/staging
readonly staged_output=$staging_directory/weather-dashboard.png
readonly render_lock=/tmp/weather-dashboard-render.lock
sleep_pid=""

stop() {
    if [ -n "$sleep_pid" ]; then
        kill "$sleep_pid" 2>/dev/null || true
    fi
    exit 0
}

trap stop INT TERM

render_dashboard() (
    if ! mkdir "$render_lock" 2>/dev/null; then
        echo "Another weather dashboard generation is already running; skipping."
        return 0
    fi
    trap 'rm -f "$staged_output"; rmdir "$render_lock"' EXIT INT TERM

    rm -f "$staged_output"
    echo "Generating the weather dashboard."

    if (
        cd "$staging_directory"
        uv run weather-dashboard \
            --latitude "$WEATHER_DASHBOARD_LATITUDE" \
            --longitude "$WEATHER_DASHBOARD_LONGITUDE" \
            --timezone Europe/London \
            --dither
    ); then
        chmod 0644 "$staged_output"
        mv "$staged_output" "$output"
        echo "Published $output."
        return 0
    fi

    echo "Weather dashboard generation failed; retaining the previous image." >&2
    return 1
)

image_is_stale() {
    [ -f "$output" ] || return 0

    modified_at=$(stat --format=%Y "$output")
    current_hour=$(($(date +%s) / 3600 * 3600))
    [ "$modified_at" -lt "$current_hour" ]
}

case "${1:-}" in
    run-now)
        render_dashboard
        exit
        ;;
    "") ;;
    *)
        echo "Usage: $0 [run-now]" >&2
        exit 2
        ;;
esac

if image_is_stale; then
    render_dashboard || true
fi

while :; do
    now=$(date +%s)
    next_hour=$(((now / 3600 + 1) * 3600))
    wait_seconds=$((next_hour - now))
    echo "Next weather dashboard generation is in $wait_seconds seconds."

    sleep "$wait_seconds" &
    sleep_pid=$!
    wait "$sleep_pid"
    sleep_pid=""

    render_dashboard || true
done
