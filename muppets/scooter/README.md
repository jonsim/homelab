# Scooter Docker stack

Scooter is a Raspberry Pi used to display a Home Assistant dashboard. The
dashboard itself is client-side; this stack supplies the standard host services:
Caddy and the Portainer Agent.

Caddy serves a small status response at `https://scooter.home.jonsim.com` and
provides an ingress point for future services. The Portainer Agent lets Gonzo's
Portainer manage Scooter's Docker engine.

## Deploy from the repo

Make `scooter.home.jonsim.com` resolve to Scooter's LAN IP in local DNS. Do not
forward ports 80, 443 or 9001 from the router. Configure the encrypted
environment on the Ansible controller, then deploy:

```sh
sops edit muppets/scooter/secrets.sops.env
uv run ansible-playbook ansible/deploy.yml --limit scooter
```

Ansible installs `/home/jon/.env` with mode `0600`. On Scooter, inspect the
stack with:

```sh
cd /home/jon
docker compose config --quiet
docker compose ps
docker compose logs --tail=100 caddy portainer-agent
```

In Gonzo's Portainer, add a Docker Standalone Agent environment named
`scooter` at `scooter.home.jonsim.com:9001` (or Scooter's LAN IP). Use the same
high-entropy `AGENT_SECRET` as the other Portainer agents. Restrict TCP 9001 to
Gonzo on the LAN; access to the agent is equivalent to root access on Scooter.
