FROM ghcr.io/astral-sh/uv:0.9.17-python3.13-bookworm-slim@sha256:4f0bb0bed02fc05d6361b4ed2c37cddd40ce6478abb222a2f30036e0888f6db5

ADD https://github.com/jonsim/weather-dashboard.git#main /app

WORKDIR /app

ENV UV_NO_SYNC=1

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir --parents /app/staging /output \
    && uv sync --frozen --no-dev --no-cache

COPY healthcheck.sh /usr/local/bin/weather-dashboard-healthcheck
COPY run.sh /usr/local/bin/run-weather-dashboard

ENTRYPOINT ["/usr/local/bin/run-weather-dashboard"]
