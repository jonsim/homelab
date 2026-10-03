#!/usr/bin/env bash

set -euo pipefail

for stack in muppets/*; do
    compose="${stack}/compose.yaml"
    if [ ! -f "${compose}" ]; then
        continue
    fi

    echo "Validating ${stack}/compose.yaml"
    docker compose \
        --env-file "${stack}/.env.example" \
        --file "${compose}" \
        config --quiet
done
