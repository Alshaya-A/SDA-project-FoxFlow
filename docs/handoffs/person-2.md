# Person 2 Handoff - Platform (GitLab + Docker)

## Scope of My Work

I own the GitLab runtime layer: how GitLab is deployed, kept healthy,
hardened, backed up, and restored.

Concretely, I deliver:
- `docker/docker-compose.yml` and `docker/.env.example`
- All scripts under `scripts/` that touch GitLab or Docker
- `docs/platform.md` and `docs/backup-restore.md`

I do **not** own: the Azure infrastructure (Person 1), the sample
application code (Person 3), or the CI/CD pipeline configuration (Person 4).

## Inputs I Need From Others

From **Person 1 (Infrastructure):**
- A running Azure VM with SSH access as `azureuser`
- A mounted data disk at `/srv/foxflow` with correct ownership
- Public IP of the VM (currently `20.127.65.116`)
- An Azure Storage Account for backups (currently `ffbackupstorage01`,
  container `gitlab-backups`)
- Prefer a VM Managed Identity with `Storage Blob Data Contributor` on the
  backup container; use the documented container-scoped SAS fallback when the
  project account cannot assign Azure roles.

From **Person 4 (CI/CD):**
- A Runner registration token from GitLab admin panel, added to `.env`
  as `GITLAB_RUNNER_TOKEN` before running `register-runner.sh`

## Outputs I Provide

For **Person 4 (CI/CD):**
- A working GitLab instance at `https://gitlab.<public-ip-with-dashes>.sslip.io`;
  Caddy forwards it internally to host port `8080`
- A registered runner ready to pick up pipeline jobs
- Admin access to configure CI/CD variables

For **Person 3 (Application):**
- A place to push the sample app repository once GitLab is up

## How to Deploy From Scratch on the Azure VM

1. SSH to the VM: `ssh azureuser@20.127.65.116`
2. Clone the repo (or copy files over)
3. Install prerequisites:
   - `./scripts/install-docker.sh`
   - `./scripts/install-azure-cli.sh` when using Managed Identity for backups
   - Log out and back in for docker group membership to apply
4. Mount the data disk with `sudo ./scripts/mount-data-disk.sh <device>`
5. `cp docker/.env.example docker/.env` and set real values
6. `./scripts/configure-gitlab.sh`
7. `./scripts/deploy.sh`
8. Retrieve initial root password (see `docs/platform.md`)
9. `./scripts/harden-gitlab.sh`
10. Generate runner token in GitLab UI, add to `.env`, then
   `./scripts/register-runner.sh`
11. `./scripts/configure-backup-cron.sh` to schedule daily backups
12. Ensure Managed Identity authorization is active, or configure the approved
    container-scoped SAS fallback, so `backup.sh` can upload to Azure Blob.

## Status at Handoff

Tested end-to-end on local dev (macOS with Docker Desktop):
- deploy.sh, health-check.sh, troubleshoot.sh, harden-gitlab.sh,
  redeploy.sh, register-runner.sh all pass
- backup-local-test.sh produces a valid archive inside the container
- backup.sh, verify-backup.sh, and configure-backup-cron.sh pass syntax checks

Validated on the Azure VM on 21 September 2026:
- `backup.sh` created and uploaded `20260921_083518_gitlab_backup.tar`
- `verify-backup.sh` downloaded the blob and validated the tar archive
- daily root cron was installed for 03:00 host time

`restore.sh` is intentionally not executed against the live instance because a
restore overwrites current GitLab data. Its syntax and download path are checked;
use it only during an authorized recovery exercise.

## Known Gotchas

- Do not run `docker compose down -v` unless you want to wipe GitLab
  data. The `-v` flag deletes named volumes.
- Do not commit `docker/.env` to Git. Only `.env.example` is safe.
- The initial root password file is deleted 24 hours after first
  reconfigure. Record it immediately or you will have to reset via
  `gitlab-rake gitlab:password:reset[root]`.
- `harden-gitlab.sh` enforces 2FA with a 48-hour grace period. If you
  cannot access an authenticator app during testing, disable via:
  `docker exec foxflow-gitlab gitlab-psql -d gitlabhq_production \
   -c "UPDATE application_settings SET require_two_factor_authentication = false;"`
- On macOS local dev, `docker-compose.yml` uses named volumes. On the Azure VM,
  run `configure-gitlab.sh` to generate bind mounts on `/srv/foxflow`.

## Contact

For any question about the platform layer, ping me (Person 2, Nada AlJuaid).
