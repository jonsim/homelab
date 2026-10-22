# Homelab

Infrastructure as code for my homelab Docker stacks.

Each host has its own directory under `muppets/` containing its Docker Compose
stack, environment template and notes.

## Hosts

- `kermit` - router:
  - _Not docker_
- `bunsen` - HA server:
  - Home Assistant
  - Weather dashboard
  - Caddy
  - Portainer Agent
- `gonzo` - service server:
  - External web stack
  - MariaDB
  - Cloudflare Tunnel
  - Caddy
  - Portainer
- `scooter` - HA dashboard:
  - Caddy
  - Portainer Agent
- `walter` - Unraid NAS:
  - Caddy
  - Portainer Agent

See the README in each host directory for configuration, deployment and
recovery instructions.

## Set up the project

Install [uv](https://docs.astral.sh/uv/), Docker with the Compose plugin,
[SOPS](https://github.com/getsops/sops) and
[age](https://github.com/FiloSottile/age). SOPS and age are required only on
the controller, not on the homelab hosts. Sync the repository's development
dependencies:

```sh
uv sync
```

Install the pre-commit hooks:

```sh
uv run pre-commit install
```

## Set up secrets

Secrets are encrypted with SOPS and age before being committed. The age public
recipient is stored in `.sops.yaml`; its private identity must remain outside
the repository.

Generate a dedicated identity on the controller:

```sh
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Back up `~/.config/sops/age/keys.txt` in a password manager or another secure
offline location. Losing every copy makes the encrypted secrets unrecoverable.
The command prints a public recipient beginning with `age1`; use it to
initialize the repository:

```sh
scripts/bootstrap-sops.sh age1...
```

The bootstrap script creates `.sops.yaml` and one encrypted
`secrets.sops.env` file per host from the corresponding `.env.example`. Replace
every placeholder by editing the encrypted files through SOPS:

```sh
sops edit muppets/bunsen/secrets.sops.env
sops edit muppets/gonzo/secrets.sops.env
sops edit muppets/scooter/secrets.sops.env
sops edit muppets/walter/secrets.sops.env
```

Verify that only encrypted values are present, then commit `.sops.yaml`, the
four stack `secrets.sops.env` files and `ansible/backup-secrets.sops.yml`. Never
commit the age identity. To give another controller or administrator access
later, add its public recipient to the creation rules and use `sops updatekeys`
on each encrypted file.

## Backups

Every managed host backs up data and configuration to a separate encrypted
Restic repository under Walter's `/mnt/user/backup` share. Kermit sends an
encrypted OPNsense configuration export to Walter first. Jobs begin at 03:00
Europe/London, retain 7 daily and 4 weekly snapshots, prune after successful
backups and run an integrity check every Sunday.

Backups on Walter protect the Raspberry Pis, Kermit's configuration, Walter's
USB configuration and Walter's unprotected NVMe application data. They do not
protect against total loss of Walter, its array, theft, fire or an operator who
can destroy both source and backup storage. Add an off-site copy before treating
this as a complete disaster-recovery strategy.

Configure the central encrypted backup settings:

```sh
sops edit ansible/backup-secrets.sops.yml
```

Generate a unique HTTP password and Restic repository password for Bunsen,
Gonzo and Scooter. Generate each matching bcrypt value with
`htpasswd -nbB <host> '<http-password>'` and store only the value after the
first colon in `http_password_hash`. Walter and Kermit use their repositories
locally and need only repository passwords. Configure distinct success and
failure healthcheck URLs for every host and keep all repository and Kermit
export passwords in the password manager that holds the SOPS age identity.

Make `backup.home.jonsim.com` resolve to Walter on the LAN and create the
restricted `kermit-backup` SFTP account described in Kermit's README. Configure
Walter's storage and credentials, deploy its stack, then install the Pi timers:

```sh
uv run ansible-playbook ansible/backup.yml --limit walter
uv run ansible-playbook ansible/deploy.yml --limit walter
uv run ansible-playbook ansible/backup.yml --limit raspberry_pis
```

Complete Kermit's SFTP setup as described in `muppets/kermit/README.md`, then
run and verify one manual backup for every host. On a Pi:

```sh
sudo systemctl start homelab-backup.service
sudo journalctl -u homelab-backup.service --since today
sudo /usr/local/sbin/homelab-backup snapshots
```

On Walter:

```sh
cd /mnt/user/appdata
docker compose exec backup-scheduler /usr/local/bin/run-backups run-now
docker compose exec backup-scheduler /usr/local/bin/run-backups snapshots walter
docker compose exec backup-scheduler /usr/local/bin/run-backups snapshots kermit
docker compose logs --tail=100 backup-scheduler rest-server
```

Perform a representative restore from every repository during setup, and a
sampled restore drill at least quarterly. A successful healthcheck proves that
the job ran; it does not replace a restore test.

## Validate a stack

Validate all four Compose models using the documented placeholder values:

```sh
./scripts/check-docker-compose.sh
```

## Bootstrap a host

Use Raspberry Pi Imager to write the 64-bit Raspberry Pi OS image appropriate
for the host. In Imager's customisation settings:

- Set the hostname to the inventory name (`bunsen`, `gonzo` or `scooter`).
- Create the `jon` account.
- Enable SSH using the controller's public key.
- Configure the locale, timezone and Wi-Fi if required.

The initial account must have passwordless `sudo`, as a standard Raspberry Pi
OS account does. Ensure the new host is reachable through the SSH alias named
in `ansible/inventory.yml`, then bootstrap it:

```sh
uv run ansible-playbook ansible/bootstrap.yml --limit scooter
```

Alternatively, use `--ask-become-pass` for interactive sudo. Normal stack
deployments and Walter's validation-only bootstrap do not require sudo.

Bootstrap upgrades the OS, installs common dependencies, configures automatic
security updates, installs Docker Engine and its Compose plugin from
[Docker's official Debian repository](https://docs.docker.com/engine/install/debian/),
and grants `jon` Docker access. Host-specific tasks install Bunsen's Bluetooth
support and configure Scooter's Chromium kiosk, desktop autologin,
network-at-boot behaviour and screen blanking using
[`raspi-config`](https://www.raspberrypi.com/documentation/computers/configuration.html).
The first successful bootstrap ends with an automatic reboot; Ansible waits for
the host to return before finishing.

Running bootstrap against Walter only validates Python, rsync and the tools
supplied by Unraid; it does not modify the Unraid operating system or Docker
installation.

## Deploy a stack

Deployment uses Ansible over SSH. Bootstrap installs the Raspberry Pi
dependencies; Unraid must already provide Python 3, rsync, Docker and the
Compose plugin. Targets do not need SOPS or an age key. The controller decrypts
the host's `secrets.sops.env` in memory and atomically installs `.env` on the
target with mode `0600`.

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

Omit `--limit` to deploy all hosts serially. Ansible preserves host-local
application data, validates the Compose model, pulls and builds images,
reconciles the stack, and waits for its health checks. Secret-bearing tasks use
`no_log`; decrypted values are never written to the controller's working tree.

## Security model

Portainer and its agents mount the Docker socket so they can manage each host.
Access to that socket is equivalent to root access: only trusted administrators
should have access to Portainer, and agent port 9001 must be reachable only from
Gonzo. All agent hosts must use the same high-entropy `AGENT_SECRET`.

SOPS protects secrets stored in Git, while the target `.env` files protect them
at runtime only through filesystem permissions. Anyone with root access or
Docker socket access on a host can read its deployed secrets. If an unencrypted
secret has ever been committed, remove it from history where appropriate and
rotate it; encrypting it in a later commit does not revoke the exposed value.
