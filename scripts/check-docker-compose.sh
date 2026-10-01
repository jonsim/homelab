#!/usr/bin/env bash

set -euo pipefail

stacks=(muppets/bunsen muppets/gonzo muppets/walter)

for stack in "${stacks[@]}"; do
    echo "Validating ${stack}/compose.yaml"
    docker compose \
        --env-file "${stack}/.env.example" \
        --file "${stack}/compose.yaml" \
        config --quiet
done
