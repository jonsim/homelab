#!/usr/bin/env bash

set -euo pipefail

stacks=(muppets/bunsen muppets/gonzo muppets/walter)

for stack in "${stacks[@]}"; do
    echo "Validating ${stack}/docker-compose.yml"
    docker compose \
        --env-file "${stack}/.env.example" \
        --file "${stack}/docker-compose.yml" \
        config --quiet
done
