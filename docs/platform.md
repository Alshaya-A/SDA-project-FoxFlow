# FoxFlow Platform - GitLab Deployment

## Overview

GitLab CE runs as a Docker container managed by Docker Compose. This document
covers deployment, day-to-day operations, and configuration for the platform layer.

## Architecture

- **GitLab CE** version pinned in `.env` (currently 17.4.2-ce.0)
- Runs in a single container named `foxflow-gitlab`
- Exposes three ports on the host:
  - HTTP: 8080 → 80 (container)
  - HTTPS: 8443 → 443 (container)
  - SSH: 2222 → 22 (container)
- Non-standard host ports chosen to avoid conflict with the host's own SSH (port 22)

## Storage

Storage strategy differs by environment:

- **Azure VM (production):** Bind mounts on `/srv/foxflow` (the mounted data disk from Terraform)
- **Local development (macOS/Windows):** Docker named volumes (`gitlab_config`, `gitlab_logs`, `gitlab_data`)

On the Azure VM, `configure-gitlab.sh` creates a Compose override with bind
mounts and the internal registry. Local development keeps the named volumes in
the base Compose file because Docker Desktop on macOS does not properly handle
the SGID permissions GitLab needs on bind mounts.

## Configuration

All environment-specific values live in `docker/.env` (never committed to Git).
Template: `docker/.env.example`.

Key variables:
- `GITLAB_VERSION` - pin to a specific CE version
- `GITLAB_HOSTNAME` - `localhost` for local dev, public IP for the Azure VM
- `GITLAB_HTTP_PORT` / `GITLAB_HTTPS_PORT` / `GITLAB_SSH_PORT` - host ports
- `FOXFLOW_DATA_PATH` - only used with bind mounts (Azure VM setup)
- `AZURE_BACKUP_STORAGE_ACCOUNT` / `AZURE_BACKUP_CONTAINER` - used by backup.sh

## First-time Deployment

1. Copy env template and edit values:
   `cp docker/.env.example docker/.env`
2. On a new Azure VM, mount the Terraform data disk:
   `sudo ./scripts/mount-data-disk.sh /dev/disk/azure/scsi1/lun0`
3. Generate and validate the Azure Compose override:
   `./scripts/configure-gitlab.sh`
4. Deploy:
   `./scripts/deploy.sh`
5. Wait for the container to become healthy (3-5 minutes on first boot).
6. Retrieve the initial root password:
   `docker exec foxflow-gitlab grep 'Password:' /etc/gitlab/initial_root_password`
7. Log in at `http://<hostname>:<http_port>` as `root` and change the password.

The `initial_root_password` file is deleted automatically 24 hours after
first reconfigure, so record it immediately.

## Day-to-day Operations

| Task | Command |
|------|---------|
| Check health | `./scripts/health-check.sh` |
| Diagnose issues | `./scripts/troubleshoot.sh` |
| Redeploy (pull new image + restart) | `./scripts/redeploy.sh` |
| Apply security hardening | `./scripts/harden-gitlab.sh` |
| Register a CI runner | `./scripts/register-runner.sh` |
| Stop GitLab | `cd docker && docker compose down` |
| Start GitLab | `cd docker && docker compose up -d` |

## Security Hardening

`harden-gitlab.sh` applies these settings:
- Disables public sign-up (admins must invite users)
- Enforces 2FA for all users (48-hour grace period)
- Sets default project visibility to Private

Re-run this script after any GitLab upgrade to re-apply the settings.

## Known Environment Notes

- On Apple Silicon Macs, the GitLab image runs under emulation (amd64 on arm64).
  Expect slower startup and slightly higher CPU use compared to the Azure VM.
- Docker Desktop on macOS occasionally resets `~/.docker/config.json` after
  restarts, which can break image pulls. Fix: `echo '{}' > ~/.docker/config.json`.
- The `troubleshoot.sh` "Disk usage" section shows "path not found" on macOS
  because storage is inside Docker volumes, not `/srv/foxflow`. This is expected.
