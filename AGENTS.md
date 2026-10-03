# Working in this repository

Read the root `README.md` and the README for every host you touch before making
changes. Those files are the source of truth for setup, requirements,
deployment, recovery and operator-facing commands; update them when behaviour
changes instead of restating that material here.

## Repository invariants

- Treat each directory under `muppets/` as an independently deployable host
  definition. Do not couple application data between host directories.
- Follow the existing host directory structure, file names, service naming,
  Compose key ordering and documentation shape. Compare with the closest
  existing host before introducing a new pattern.
- Prefer shared Ansible roles, group variables, Compose conventions and helper
  scripts over host-specific implementations. A genuine host difference should
  be expressed as a small variable or focused role task rather than a parallel
  framework.
- Keep host lists alphabetical everywhere and keep related declarations in the
  same relative order. Use consistent names for equivalent services, volumes,
  environment variables and inventory fields.
- Keep host membership synchronized across the Ansible inventory, validation
  scripts, SOPS bootstrap script and root host summary when adding or removing
  a Docker host.
- Keep `.env.example`, Compose interpolation and the corresponding
  `secrets.sops.env` keys aligned. Secret values belong only in SOPS-encrypted
  files; never print decrypted content into logs or the working tree.
- Pin container images by version and digest, following the existing Compose
  files. Keep each Portainer Agent compatible with Gonzo's Portainer Server.
- Preserve host-local state during synchronization. Add persistent application
  data to the host's `stack_rsync_excludes` rather than allowing deployment to
  overwrite it.
- Caddy images use the Cloudflare DNS module. A host with a Caddy configuration
  must remain included in the Caddy validation script.

## Ansible boundaries

- `bootstrap.yml` owns Raspberry Pi OS preparation and must remain idempotent.
  Prefer Ansible modules after its minimal raw Python bootstrap. New Raspberry
  Pi host behavior should live in a role or host/group variables, not a long
  host-specific conditional in the playbook.
- All managed hosts provide Python. Prefer idempotent Ansible modules to raw or
  shell commands; use raw only for the initial Raspberry Pi Python bootstrap.
- Unraid owns its base system and Docker installation. Bootstrap may validate
  Walter, but must not manage Unraid packages or replace its Docker runtime.
- Reboots and service restarts must be handlers or otherwise conditional. A
  second bootstrap run should converge without unnecessary disruption.
- Do not run bootstrap or deployment against physical hosts merely to validate
  a repository change. Limit live-host operations to an explicit user request.

## Change discipline

- Preserve unrelated working-tree changes and encrypted files.
- Prioritize neatness. Remove obsolete scaffolding, avoid duplicate
  configuration, and leave files easier to scan than before. Do not add
  abstractions until at least two hosts benefit from them.
- Your goal isn't the smallest change possible, it's the smallest coherent
  change. Think holistically and prioritise elegant design: ask yourself "if I
  were implementing this from scratch, what approach would I choose?".
- When refactoring, apply patterns consistently across the entire repository,
  rather than narrowly refactoring just one area.
- When introducing new patterns, prefer migrating away from legacy patterns and
  names rather than retaining permanent compatibility aliases.
- Keep formatting, indentation, comments and section placement consistent with
  neighboring files. Avoid one-off exceptions when an existing convention can
  represent the same behavior clearly.
- Use the repository's existing pinned toolchain and checks. Run checks that
  cover every file type changed, plus Ansible inventory and syntax validation
  for Ansible changes.
- Treat Docker socket access, Portainer Agent exposure and decrypted runtime
  environment files as root-equivalent security boundaries.
- Keep documentation factual and host-specific. Avoid copying shared guidance
  into multiple host READMEs when a root-level reference is sufficient.
