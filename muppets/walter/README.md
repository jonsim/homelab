# Walter Docker stack

Caddy serves the Unraid WebGUI at `https://walter.home.jonsim.com` using a
Cloudflare DNS-01 certificate. The Portainer Agent lets Gonzo's Portainer manage
Walter's Docker engine. Both run on Unraid's built-in Docker engine.

## Storage layout

- Four 4 TB HDDs form the Unraid array: two parity disks and two data disks,
  providing about 8 TB usable capacity and protection against two HDD failures.
- The `backup` and `media` shares live on the array, with no secondary storage.
- The 256 GB NVMe is a single-device pool named `local`. The `appdata` and
  `system` shares live there, with no secondary storage. This pool has no disk
  redundancy and is not protected by the HDD parity disks.

## Before starting Caddy

### Requirements

- Unraid with its built-in Docker service enabled
- SSH access for the deployment account with permission to run Docker
- Python 3 and `rsync` available on the host
- The Docker Compose plugin
- Persistent storage available under `/mnt/user/appdata`
- Nothing else listening on TCP 80 or TCP/UDP 443 after the WebGUI is moved
- TCP 9001 reachable from Gonzo, but not from the Internet

`ansible/bootstrap.yml` validates these requirements but deliberately does not
install or reconfigure packages managed by Unraid.
Install **Python 3 for UNRAID** and **Compose Manager Plus** from Unraid's
**Apps** tab, then confirm `python3 --version` and `docker compose version`
work. Compose Manager Plus provides the Compose CLI plugin; Docker Engine
alone does not include that command on Unraid.

1. In Unraid, go to **Settings → Management Access**. Set **Use SSL/TLS** to
   **No** and change **HTTP port** from `80` to `8080`, then apply. Confirm
   `http://<walter-LAN-IP>:8080` works before deploying Caddy. Do not forward
   8080, 80 or 443 from the router to Walter. The direct 8080 URL is an
   emergency fallback; it is unencrypted and should be limited to a trusted
   LAN. If Unraid Connect Remote Access is enabled, disable it first: it
   requires Unraid's own HTTPS access.
2. In OPNsense, make `walter.home.jonsim.com` resolve to Walter's LAN IP for
   local clients. DNS-01 validates domain control, but does not create this
   client-facing DNS record. No public A record or port forwarding is needed.
3. Enable Unraid's built-in Docker service under **Settings → Docker**. Keep
   `appdata` and `system` on the NVMe `local` pool. This stack stores Caddy's
   certificates under `/mnt/user/appdata/caddy` so they survive rebuilds.

## Deploy from the repo

Configure Walter's encrypted environment on the Ansible controller and deploy
it:

```sh
sops edit muppets/walter/secrets.sops.env
uv run ansible-playbook ansible/deploy.yml --limit walter
```

Ansible installs `/mnt/user/appdata/.env` with mode `0600`. On Walter, from
that directory, inspect and operate the deployed stack:

```sh
docker compose config --quiet
docker compose up -d --build
docker compose logs --tail=100 caddy
docker compose logs --tail=100 portainer-agent
```

The token needs **Zone:Read** and **DNS:Edit** for only the `jonsim.com` zone.
It can be a separate token from Gonzo's Caddy token. Never commit the decrypted
`.env`.

Visit `https://walter.home.jonsim.com` after Caddy obtains a certificate.
In Gonzo's Portainer, go to **Environments → Add environment → Docker
Standalone → Agent**. Name it `walter` and enter `walter.home.jonsim.com:9001`
(or `<walter-LAN-IP>:9001`) as the environment address, without `https://`.
Gonzo must be able to reach Walter on TCP 9001. The agent speaks HTTPS itself;
it is not routed through Caddy. Do not port-forward 9001 to the Internet, and
restrict access to it to Gonzo in your LAN firewall if possible. The agent has
root-equivalent access to Walter's Docker socket. Set `AGENT_SECRET` to the same
high-entropy value used on Gonzo and Bunsen.

Portainer can observe this stack through the Walter agent, but manage this
stack from these Compose files to keep one source of truth. The agent mount
assumes Unraid's Docker volume directory is `/var/lib/docker/volumes`; check
`docker info --format '{{.DockerRootDir}}'` on Walter if you have changed its
Docker storage configuration.

For future services on Walter, add another site block to `caddy/Caddyfile`
and redeploy with `docker compose up -d --build`. The custom Caddy image is
needed because the stock image does not include the Cloudflare DNS module.
