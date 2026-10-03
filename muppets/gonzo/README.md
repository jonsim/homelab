# RPi Web Stack — quick start

## Layout
```
rpi-web-stack/
├── compose.yaml
├── .env.example           → documents the required values
├── secrets.sops.env       → encrypted deployment values
├── nginx/default.conf
├── php/Dockerfile
└── www/              → put your website files here (index.php, .html, etc.)
```

## Steps on the Pi

### Requirements

- A Raspberry Pi running 64-bit Raspberry Pi OS Lite
- An SSH server and a `jon` account with passwordless `sudo` for bootstrap
- Nothing else listening on TCP 80 or TCP/UDP 443
- Enough persistent storage for the website, MariaDB and Portainer data

`ansible/bootstrap.yml` installs the host utilities, Docker Engine and the
Docker Compose plugin, and grants `jon` Docker access.

1. From the repository root on the control machine, run
   `sops edit muppets/gonzo/secrets.sops.env`, replace every placeholder, then
   run `uv run ansible-playbook ansible/deploy.yml --limit gonzo`. Ansible
   installs the decrypted environment at `~/.env` with mode `0600`.

2. Put your site files (the ones you downloaded from cPanel) into `www/`.

3. Edit the encrypted environment on the controller when values change:
   ```
   sops edit muppets/gonzo/secrets.sops.env
   ```
   Fill in real database credentials. Generate a high-entropy `AGENT_SECRET`
   and use that same value for the Portainer agents on Bunsen and Walter. Leave
   `TUNNEL_TOKEN` for now if you haven't created the Cloudflare tunnel yet —
   just start the stack without cloudflared running
   (`docker compose up -d caddy php db portainer`) and add it later.

4. Ensure local DNS resolves `portainer.home.jonsim.com` to Gonzo's LAN
   address, then validate and bring the stack up:
   ```
   docker compose config --quiet
   docker compose up -d --build
   ```

   Portainer is included in the stack and is available at
   `https://portainer.home.jonsim.com`. Caddy terminates HTTPS using a
   publicly trusted certificate obtained with a Cloudflare DNS-01 challenge.
   Create the initial administrator account, then select the local Docker
   environment.

5. Import your database dump into the `db` container:
   ```
   docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" changeme_db_name < your_dump.sql
   ```
   (swap in your real DB name from the deployed `.env`)

6. Test locally before touching Cloudflare/DNS at all:
   ```
   docker compose exec caddy wget --quiet --output-document=- http://localhost
   ```
   or from another machine on your LAN, temporarily add `ports: ["8080:80"]`
   under the nginx service, `docker compose up -d nginx`, and browse to
   `http://<pi-ip>:8080`. Remove the ports line again once you're happy —
   it's only for local testing, not needed for the tunnel.

## Notes
- PHP is pinned to 8.2 in `php/Dockerfile` — check what your old host ran
  (`php -v` if you had shell access, or it's usually shown in cPanel's
  "MultiPHP Manager") and change the base image tag if needed.
- Caddy is the LAN entry point and publishes HTTP and HTTPS on ports `80` and
  `443`. Do not forward these ports from your router unless you deliberately
  intend to publish a service.
- Portainer is not published directly on a host port. Caddy reaches it at
  `portainer:9000` over the private `webnet` Docker network. The Docker socket
  mount gives Portainer root-equivalent control of the Docker host. Restrict
  Portainer administration to trusted users.
- Database data persists in the `db_data` Docker volume even if you
  recreate containers. Set up a cron `mysqldump` backup once things are
  stable — that volume is now your only copy of the data.
- Portainer configuration persists in the `portainer_data` Docker volume.
  Avoid `docker compose down -v` unless you intend to delete both Portainer
  configuration and the database volume.
- The volumes retain their historical `jon_*` Docker names so deployments made
  before the Compose project was explicitly named continue using the existing
  database, Caddy and Portainer data.
