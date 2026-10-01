# Homelab

Infrastructure as code for my homelab Docker stacks.

Each host has its own directory containing its Docker Compose stack,
environment template and notes.

## Hosts

- `bunsen` - HA server:
  - Home Assistant
  - Caddy
  - Portainer Agent
- `gonzo` - service server:
  - External web stack
  - MariaDB
  - Cloudflare Tunnel
  - Caddy
  - Portainer
- `walter` - Unraid NAS:
  - Caddy
  - Portainer Agent

See the README in each host directory for configuration, deployment and
recovery instructions.

## Set up the project

Install [uv](https://docs.astral.sh/uv/), `docker` and `docker-compose`.


Sync the remainder of the repositories dependencies:

```sh
uv sync
```

Install the pre-commit hooks:

```sh
uv run pre-commit install
```

The real environment files contain secrets and are not committed. Copy the
relevant template before configuring a host:

```sh
cp <host>/.env.example <host>/.env
chmod 600 <host>/.env
```

## Validate a stack

Run Docker Compose validation from the host directory:

```sh
cd <host>
docker compose config --quiet
```

## Deploy a stack

The deployment scripts copy the tracked configuration to their corresponding
hosts over SSH:

```sh
./deploy-bunsen.sh
./deploy-gonzo.sh
./deploy-walter.sh
```

Review the destination host's README before deploying.
