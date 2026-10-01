#!/usr/bin/env bash

set -euo pipefail

readonly caddy_image="caddy:2.11.4-alpine@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b"
readonly placeholder_cloudflare_token="0123456789abcdef0123456789abcdef01234567"
readonly stacks=(muppets/bunsen muppets/gonzo muppets/walter)

status=0
tmp_file=""
trap 'rm -f "$tmp_file"' EXIT

for stack in "${stacks[@]}"; do
    caddyfile="${stack}/caddy/Caddyfile"
    tmp_file=$(mktemp)

    echo "Checking Caddy formatting: ${caddyfile}"
    docker run --rm --tty \
        --volume "${PWD}/${caddyfile}:/etc/caddy/Caddyfile:ro" \
        --entrypoint caddy "$caddy_image" \
        fmt /etc/caddy/Caddyfile | tr -d '\r' > "$tmp_file"
    if ! diff --unified "$caddyfile" "$tmp_file"; then
        status=1
    fi
    rm -f "$tmp_file"
    tmp_file=""

    echo "Building and validating Caddy config: ${caddyfile}"
    docker compose \
        --env-file "${stack}/.env.example" \
        --file "${stack}/compose.yaml" \
        build caddy
    caddy_image_id=$(docker image inspect \
        "${stack##*/}-caddy:latest" --format '{{.Id}}')
    docker run --rm \
        --env-file "${stack}/.env.example" \
        --env "CLOUDFLARE_API_TOKEN=${placeholder_cloudflare_token}" \
        --volume "${PWD}/${caddyfile}:/etc/caddy/Caddyfile:ro" \
        --entrypoint caddy "$caddy_image_id" \
        validate --config /etc/caddy/Caddyfile --adapter caddyfile
done

exit "$status"
