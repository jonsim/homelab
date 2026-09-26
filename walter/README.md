# Walter reverse proxy

Caddy serves the Unraid WebGUI at `https://walter.home.jonsim.com` using a
Cloudflare DNS-01 certificate. It runs on Unraid's built-in Docker engine.

## Before starting Caddy

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

Copy the `walter` directory to a persistent location on Walter, for example
`/mnt/user/appdata/stacks/walter`. On Walter, from that directory:

```sh
cp .env.example .env
chmod 600 .env
# Edit .env and set the Cloudflare API token.
docker compose config --quiet
docker compose up -d --build
docker compose logs --tail=100 caddy
```

The token needs **Zone:Read** and **DNS:Edit** for only the `jonsim.com` zone.
It can be a separate token from Gonzo's Caddy token. Never commit `.env`.

Visit `https://walter.home.jonsim.com` after Caddy obtains a certificate.
Portainer on Gonzo can observe this container through the Walter agent, but
manage this stack from these Compose files to keep one source of truth.

For future services on Walter, add another site block to `caddy/Caddyfile`
and redeploy with `docker compose up -d --build`. The custom Caddy image is
needed because the stock image does not include the Cloudflare DNS module.
