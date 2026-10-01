# Bunsen Home Assistant stack

This stack runs Home Assistant Container, Caddy and a Portainer Agent on the
Raspberry Pi 5 named `bunsen`. Caddy obtains and renews a publicly trusted
certificate using a Cloudflare DNS-01 challenge, then proxies HTTPS traffic to
Home Assistant. The Portainer Agent lets the Portainer Server on Gonzo manage
Bunsen's Docker engine.

Both services use host networking. Home Assistant therefore retains LAN device
discovery, while Caddy can reach it at `127.0.0.1:8123`. Caddy publishes TCP
ports 80 and 443, plus UDP 443 for HTTP/3, directly on the host.

## Host prerequisites

- A 64-bit Linux installation on the Raspberry Pi 5
- Docker Engine 23 or later with Docker Compose
- D-Bus and BlueZ on the host if Home Assistant will use Bluetooth
- Nothing else listening on TCP 80 or TCP/UDP 443
- TCP 9001 reachable from Gonzo, but not from the Internet

The Home Assistant container is privileged, matching Home Assistant's general
Raspberry Pi container guidance and allowing attached radios to be discovered.
Inside Home Assistant, prefer stable device paths under `/dev/serial/by-id/`
when configuring USB Zigbee or Z-Wave controllers.

## Configure the stack

Configure the encrypted environment file on the Ansible controller:

```sh
sops edit muppets/bunsen/secrets.sops.env
```

Set a Cloudflare API token. Restrict the token to the
`jonsim.com` zone and grant only `Zone:Read` and `DNS:Edit`. Change `HA_DOMAIN`
if the default `homeassistant.home.jonsim.com` name is not desired. Deploying
through Ansible decrypts this file and installs `/home/homeassistant/.env` on
Bunsen with mode `0600`.

Make local DNS resolve `HA_DOMAIN` to Bunsen's LAN address. DNS-01 proves
control of the domain but does not create the client-facing A or AAAA record.
For LAN-only use, a local DNS override is sufficient and no router port
forwarding is required. For public remote access, publish the appropriate DNS
record and forward TCP 443 to Bunsen deliberately.

## Restore Home Assistant

Start Home Assistant without Caddy first:

```sh
docker compose config --quiet
docker compose up -d homeassistant
docker compose logs --tail=100 -f homeassistant
```

Open `http://<bunsen-lan-address>:8123`. During onboarding, upload the backup
from the previous Home Assistant OS installation and enter its backup emergency
kit key. The restored configuration is stored in `homeassistant/config`.

After the restore, check radios, integrations, entities and automations using
the direct port 8123 address before introducing the reverse proxy.

## Enable the TLS proxy

In Home Assistant, go to **Settings > System > Network > HTTP server** and:

1. Enable **Trust X-Forwarded-For**.
2. Add `127.0.0.1` to **Trusted proxies**.
3. Save and confirm the settings after Home Assistant restarts.

Caddy connects over IPv4 loopback, so only that single proxy address needs to
be trusted. Start Caddy and inspect certificate issuance:

```sh
docker compose up -d --build caddy
docker compose logs --tail=100 -f caddy
```

Home Assistant should then be available at the HTTPS URL configured by
`HA_DOMAIN`. Port 8123 remains available on the trusted LAN as an emergency
fallback.

## Connect Portainer on Gonzo

The Portainer Agent publishes TCP 9001 on Bunsen. It speaks HTTPS itself and is
not routed through Caddy. After starting the stack, open Portainer on Gonzo and
go to **Environments > Add environment > Docker Standalone > Agent**. Use:

- Name: `bunsen`
- Environment address: `bunsen.home.jonsim.com:9001` or Bunsen's LAN IP and
  port 9001

Do not include `http://` or `https://` in the environment address. The initial
agent claim must be completed within five minutes of the agent starting. If it
times out before it is claimed, restart it with:

```sh
docker compose restart portainer-agent
```

The agent's Docker socket mount grants Portainer root-equivalent control of
Bunsen. Set `AGENT_SECRET` to the same high-entropy value used by Gonzo's
Portainer Server and Walter's agent. Set `PORTAINER_AGENT_BIND_ADDRESS` to
Bunsen's LAN address, and restrict TCP 9001 at the host or network firewall so
only Gonzo can connect. Never forward port 9001 from the router.

The volume mount assumes Docker stores named volumes in
`/var/lib/docker/volumes`. Confirm Bunsen's Docker root with
`docker info --format '{{.DockerRootDir}}'` and adjust the left side of that
mount if it has been changed.

## Operations

Validate the Compose model:

```sh
docker compose config --quiet
```

View status and recent logs:

```sh
docker compose ps
docker compose logs --tail=100 homeassistant caddy portainer-agent
```

Reload Caddy after editing `caddy/Caddyfile`:

```sh
docker compose exec -w /etc/caddy caddy caddy reload
```

To update Home Assistant, first create and export a backup, change
`HOME_ASSISTANT_VERSION` in `.env`, and then run:

```sh
docker compose pull homeassistant
docker compose up -d homeassistant
docker compose logs --tail=100 -f homeassistant
```

To update Caddy, change `CADDY_VERSION`, rebuild, and recreate it:

```sh
docker compose build --pull caddy
docker compose up -d caddy
```

Keep the Portainer Agent on the same version as the Portainer Server. Update the
server on Gonzo first, then recreate the agent:

```sh
docker compose pull portainer-agent
docker compose up -d portainer-agent
```

Back up `homeassistant/config` and the `bunsen_caddy_data` Docker volume. The
latter contains Caddy's ACME account, certificates and private keys. Do not run
`docker compose down -v` unless deleting that persistent data is intentional.
