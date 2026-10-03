# Kermit OPNsense configuration backup

Kermit is rebuilt from an OPNsense installation image; only its encrypted
configuration export is backed up. Runtime state, logs, RRD statistics and the
installed operating system are intentionally excluded.

Install OPNsense's `os-sftp-backup` plugin. On Walter, create a dedicated
SFTP-only account named `kermit-backup` which can write only to
`/mnt/user/appdata/homelab-backup/kermit-inbox`, and use a dedicated SSH key
generated for Kermit. Create this account before running `ansible/backup.yml`;
the play assigns its inbox with mode `0700` and fails rather than falling back
to a shared account. Do not reuse an administrator's SSH key. In the plugin,
configure that SFTP destination, set Backup Count to `1`, and set Encrypt
Password to the `export_password` stored in
`ansible/backup-secrets.sops.yml`.

Under **System > Settings > Cron**, add a nightly `03:00` job for **Remote
backup** (`configctl system remote backup`). Walter's scheduler waits for an XML
export newer than 30 minutes, then snapshots the staging directory into the
encrypted `/mnt/user/backup/kermit` Restic repository. A missing or stale
export triggers Kermit's failure healthcheck.

Test the SFTP connection in the plugin, trigger the cron command once, and then
run Walter's backup scheduler manually. Confirm both the encrypted XML in the
staging directory and a Kermit Restic snapshot exist.

To recover Kermit, install a compatible OPNsense release, restore the selected
encrypted XML through **System > Configuration > Backups**, enter the separately
stored export password, reboot, and validate interface assignments, DNS,
firewall policy, VPNs and administrative access before reconnecting the WAN.
