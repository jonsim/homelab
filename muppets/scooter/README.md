# Scooter Docker stack

Scooter is a Raspberry Pi used to display a Home Assistant dashboard. The
dashboard itself is client-side. Chromium starts in kiosk mode when the `jon`
desktop session logs in, while Docker supplies the standard host services:
Caddy and the Portainer Agent.

Caddy serves a small status response at `https://scooter.home.jonsim.com` and
provides an ingress point for future services. The Portainer Agent lets Gonzo's
Portainer manage Scooter's Docker engine.

## Deploy from the repo

### Requirements

- A Raspberry Pi running 64-bit Raspberry Pi OS with Desktop
- An SSH server and a `jon` account with passwordless `sudo` for bootstrap
- Nothing else listening on TCP 80 or TCP/UDP 443
- TCP 9001 reachable from Gonzo, but not from the Internet
- Local network access to the Home Assistant URL configured by `KIOSK_URL`

`ansible/bootstrap.yml` installs the host utilities, Docker Engine, the Docker
Compose plugin and Chromium. It also enables desktop autologin for `jon`, waits
for networking during boot and disables desktop screen blanking.

Bootstrap installs the launcher at `/usr/local/bin/home-assistant-kiosk` and
configures it in `/home/jon/.config/labwc/autostart`.

Make `scooter.home.jonsim.com` resolve to Scooter's LAN IP in local DNS. Do not
forward ports 80, 443 or 9001 from the router. Configure the encrypted
environment on the Ansible controller, including the full `KIOSK_URL` for the
desired Home Assistant dashboard, then deploy:

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

Log out and back in, or reboot Scooter, to start the kiosk after its first
deployment. To test it from the graphical desktop, run
`/usr/local/bin/home-assistant-kiosk`. Dashboard authentication remains in Chromium's
profile, so Home Assistant may require one initial interactive sign-in.

In Gonzo's Portainer, add a Docker Standalone Agent environment named
`scooter` at `scooter.home.jonsim.com:9001` (or Scooter's LAN IP). Use the same
high-entropy `AGENT_SECRET` as the other Portainer agents. Restrict TCP 9001 to
Gonzo on the LAN; access to the agent is equivalent to root access on Scooter.
