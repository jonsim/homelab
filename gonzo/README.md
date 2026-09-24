# RPi Web Stack — quick start

## Layout
```
rpi-web-stack/
├── docker-compose.yml
├── .env.example      → copy to .env and fill in real values
├── nginx/default.conf
├── php/Dockerfile
└── www/              → put your website files here (index.php, .html, etc.)
```

## Steps on the Pi

1. Install Docker + Compose (if not already):
   ```
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```
   Log out and back in for the group change to apply.

2. Copy this whole `rpi-web-stack` folder to the Pi (scp, git, USB — whatever's easiest).

3. Put your site files (the ones you downloaded from cPanel) into `www/`.

4. Copy the env file and edit it:
   ```
   cp .env.example .env
   nano .env
   ```
   Fill in real database credentials. Leave `TUNNEL_TOKEN` for now if you haven't
   created the Cloudflare tunnel yet — just start the stack without cloudflared
   running (`docker compose up -d nginx php db`) and add it later.

5. Bring the stack up:
   ```
   docker compose up -d
   ```

6. Import your database dump into the `db` container:
   ```
   docker exec -i web-db mysql -u root -p"$MYSQL_ROOT_PASSWORD" changeme_db_name < your_dump.sql
   ```
   (swap in your real DB name from `.env`)

7. Test locally before touching Cloudflare/DNS at all:
   ```
   docker exec -it web-nginx curl localhost
   ```
   or from another machine on your LAN, temporarily add `ports: ["8080:80"]`
   under the nginx service, `docker compose up -d nginx`, and browse to
   `http://<pi-ip>:8080`. Remove the ports line again once you're happy —
   it's only for local testing, not needed for the tunnel.

## Notes
- PHP is pinned to 8.2 in `php/Dockerfile` — check what your old host ran
  (`php -v` if you had shell access, or it's usually shown in cPanel's
  "MultiPHP Manager") and change the base image tag if needed.
- No ports are published for nginx or db in the compose file by design —
  once cloudflared is running, it reaches nginx over the internal Docker
  network only.
- Database data persists in the `db_data` Docker volume even if you
  recreate containers. Set up a cron `mysqldump` backup once things are
  stable — that volume is now your only copy of the data.
