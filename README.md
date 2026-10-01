# Homelab

Infrastructure as code for my homelab Docker stacks.

Each host has its own directory under `muppets/` containing its Docker Compose
stack, environment template and notes.

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

Install [uv](https://docs.astral.sh/uv/) and Docker with the Compose plugin.
Sync the repository's development dependencies:

```sh
uv sync
```

Install the pre-commit hooks:

```sh
uv run pre-commit install
```

The real environment files contain secrets, remain on their target hosts with
mode `0600`, and are never synchronized back into the repository.

## Validate a stack

Run Docker Compose validation from the host directory:

```sh
cd muppets/<host>
docker compose config --quiet
```

## Deploy a stack

Deployment uses Ansible over SSH without requiring Python on the target. Each
target needs an SSH server, `rsync`, Docker with the Compose plugin, a
configured `.env` file at the deployment path, and a matching SSH host alias.

Install the pinned Ansible collection:

```sh
uv run ansible-galaxy collection install -r ansible/requirements.yml
```

Check connectivity and preview a deployment:

```sh
uv run ansible homelab -m raw -a 'printf pong'
uv run ansible-playbook ansible/deploy.yml --check --diff --limit gonzo
```

Deploy one host after reviewing its README:

```sh
uv run ansible-playbook ansible/deploy.yml --limit gonzo
```

On a host's first deployment, Ansible creates `.env` from `.env.example` with
mode `0600` and stops. Edit every placeholder on that host, then rerun the same
command.

Omit `--limit` to deploy all hosts serially. Ansible preserves host-local
secrets and application data, validates the Compose model, pulls and builds
images, reconciles the stack, and waits for its health checks.

## Security model

Portainer and its agents mount the Docker socket so they can manage each host.
Access to that socket is equivalent to root access: only trusted administrators
should have access to Portainer, and agent port 9001 must be reachable only from
Gonzo. All three hosts must use the same high-entropy `AGENT_SECRET`.
