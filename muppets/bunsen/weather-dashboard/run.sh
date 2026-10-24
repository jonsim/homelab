#!/bin/sh

set -eu

readonly output=/output/weather-dashboard.png
readonly staging_directory=/app/staging
readonly staged_output=$staging_directory/weather-dashboard.png
readonly render_lock=/tmp/weather-dashboard-render.lock
readonly schedule_minute=54
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

    attempt=1
    for retry_delay in 0 10 20 30 60 180; do
        if [ "$retry_delay" -gt 0 ]; then
            echo "Retrying weather dashboard generation in $retry_delay seconds."
            sleep "$retry_delay"
        fi

        rm -f "$staged_output"
        echo "Generating the weather dashboard (attempt $attempt of 6)."

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

        attempt=$((attempt + 1))
    done

    echo "Weather dashboard generation failed after 6 attempts; retaining the previous image." >&2
    return 1
)

image_is_stale() {
    [ -f "$output" ] || return 0

    modified_at=$(stat --format=%Y "$output")
    now=$(date +%s)
    latest_run=$((now / 3600 * 3600 + schedule_minute * 60))
    if [ "$latest_run" -gt "$now" ]; then
        latest_run=$((latest_run - 3600))
    fi
    [ "$modified_at" -lt "$latest_run" ]
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
    next_run=$((now / 3600 * 3600 + schedule_minute * 60))
    if [ "$next_run" -le "$now" ]; then
        next_run=$((next_run + 3600))
    fi
    wait_seconds=$((next_run - now))
    echo "Next weather dashboard generation is in $wait_seconds seconds."

    sleep "$wait_seconds" &
    sleep_pid=$!
    wait "$sleep_pid"
    sleep_pid=""

    render_dashboard || true
done
