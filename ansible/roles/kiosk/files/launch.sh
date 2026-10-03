#!/usr/bin/env sh

set -eu

readonly environment_file=/home/jon/.env

if [ ! -r "$environment_file" ]; then
    echo "Cannot read $environment_file" >&2
    exit 1
fi

KIOSK_URL=$(sed -n 's/^KIOSK_URL=//p' "$environment_file")
readonly KIOSK_URL

if [ -z "$KIOSK_URL" ]; then
    echo "Set KIOSK_URL in $environment_file" >&2
    exit 1
fi

if command -v chromium-browser >/dev/null 2>&1; then
    browser=chromium-browser
elif command -v chromium >/dev/null 2>&1; then
    browser=chromium
else
    echo "Chromium is not installed" >&2
    exit 1
fi

exec "$browser" \
    --kiosk \
    --no-first-run \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-translate \
    "$KIOSK_URL"
