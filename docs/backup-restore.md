# FoxFlow Backup and Restore

This document covers how GitLab data is backed up, verified, and restored.

## Backup Strategy

- GitLab's built-in `gitlab-backup create` produces a single `.tar` archive
  containing the database, repositories, uploads, artifacts, LFS objects,
  and other application data.
- The archive is then uploaded to Azure Blob Storage for off-site retention.
- **Not included in the tar:** `/etc/gitlab/gitlab.rb` and `/etc/gitlab/gitlab-secrets.json`.
  These live inside the `gitlab_config` volume and must be backed up separately
  (a full config snapshot is out of scope for the initial version).

## Backup Schedule

- `backup.sh` runs on demand.
- `configure-backup-cron.sh` installs a daily cron job at 03:00 (host time)
  that calls `backup.sh` and appends output to `../backup.log`.

## What backup.sh Does

1. Runs `gitlab-backup create BACKUP=<timestamp>` inside the container.
2. Validates that the resulting `.tar` file exists at the expected path
   (`${FOXFLOW_DATA_PATH}/gitlab/data/backups/`).
3. Uploads the file to Azure Blob Storage using `az storage blob upload`
   with `--auth-mode login`, so no access keys are stored in `.env`.

## Environment Requirements

- Azure CLI (`az`) installed on the VM (see `install-azure-cli.sh`).
- The VM's Managed Identity (or the logged-in az user) must have
  `Storage Blob Data Contributor` on the backup container.
- The following variables in `.env`:
  - `AZURE_BACKUP_STORAGE_ACCOUNT`
  - `AZURE_BACKUP_CONTAINER`
  - `FOXFLOW_DATA_PATH`

## Verifying Backups

`verify-backup.sh` downloads the latest blob from Azure and runs `tar -tf`
against it. This confirms:
- A backup exists in Azure.
- The archive is not corrupted in transit.

Run this at least weekly, or wire it into a monitoring alert.

## Restoring

`restore.sh <BACKUP_TIMESTAMP>` performs a full restore:

1. Downloads the specified backup from Azure.
2. Stops `puma` and `sidekiq` inside the container (keeping PostgreSQL up).
3. Runs `gitlab-backup restore BACKUP=<timestamp> force=yes`.
4. Restarts GitLab.

**Warning:** Restore is destructive - it overwrites the current GitLab
database and repositories with the backup contents. Only run against a
GitLab instance you intend to replace.

## Local Development Note

On macOS local dev, storage is inside a Docker volume, not `/srv/foxflow`.
The backup file lands at `/var/opt/gitlab/backups/` inside the container.
To inspect it locally:


The full `backup.sh` upload flow is designed for the Azure VM. On a local
Mac, use `backup-local-test.sh` instead - it exercises the same
`gitlab-backup create` step without the Azure upload.

## Retention

Currently no automated cleanup is configured. GitLab's own
`gitlab_rails['backup_keep_time']` can be set in `gitlab.rb.template`
to auto-prune old backups (in seconds). For remote retention, use an
Azure Blob lifecycle policy on the container.
