#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly repository_root
cd "$repository_root"

if [[ $# -ne 1 || ! $1 =~ ^age1[0-9a-z]+$ ]]; then
    echo "Usage: $0 age1..." >&2
    exit 2
fi

if ! command -v sops >/dev/null; then
    echo "sops is required and must be available on PATH." >&2
    exit 1
fi

if [[ -e .sops.yaml ]]; then
    echo ".sops.yaml already exists; refusing to overwrite it." >&2
    exit 1
fi

for stack in muppets/bunsen muppets/gonzo muppets/walter; do
    if [[ -e "${stack}/secrets.sops.env" ]]; then
        echo "${stack}/secrets.sops.env already exists; refusing to overwrite it." >&2
        exit 1
    fi
done

recipient=$1
sed "s/AGE_RECIPIENT/${recipient}/" .sops.yaml.example > .sops.yaml

for stack in muppets/bunsen muppets/gonzo muppets/walter; do
    encrypted_file="${stack}/secrets.sops.env"
    cp "${stack}/.env.example" "$encrypted_file"
    sops encrypt --in-place "$encrypted_file"
    echo "Created ${encrypted_file}"
done

echo "Created .sops.yaml"
echo "Edit each encrypted file with: sops edit muppets/<host>/secrets.sops.env"
