#!/bin/sh

set -eu

readonly image=/output/weather-dashboard.png
readonly maximum_age_seconds="${WEATHER_DASHBOARD_MAXIMUM_AGE_SECONDS:-7500}"

[ -f "$image" ]

modified_at=$(stat --format=%Y "$image")
age=$(($(date +%s) - modified_at))
[ "$age" -ge 0 ]
[ "$age" -le "$maximum_age_seconds" ]

exec /app/.venv/bin/python -c \
    'from PIL import Image; image = Image.open("/output/weather-dashboard.png"); image.verify(); assert image.size == (800, 480)'
