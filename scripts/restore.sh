#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
set -a; source "$DOCKER_DIR/.env"; set +a

BACKUP_TIMESTAMP="${1:-}"
if [[ -z "$BACKUP_TIMESTAMP" ]]; then
  log_error "Usage: ./restore.sh <BACKUP_TIMESTAMP>  (e.g. 20261015_030000)"
  exit 1
fi

CONTAINER="foxflow-gitlab"
BLOB_NAME="${BACKUP_TIMESTAMP}_gitlab_backup.tar"
BACKUP_DIR="${GITLAB_BACKUP_DIR:-${FOXFLOW_DATA_PATH}/data/backups}"
LOCAL_PATH="${BACKUP_DIR}/${BLOB_NAME}"

log_info "Downloading backup $BLOB_NAME from Azure..."
if [[ -n "${AZURE_BACKUP_SAS_TOKEN:-}" ]]; then
  require_command curl
  SAS_TOKEN="${AZURE_BACKUP_SAS_TOKEN#\?}"
  BLOB_URL="https://${AZURE_BACKUP_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_BACKUP_CONTAINER}/${BLOB_NAME}?${SAS_TOKEN}"
  curl --fail-with-body --silent --show-error \
    "$BLOB_URL" \
    --output "$LOCAL_PATH"
else
  require_command az
  az storage blob download \
    --account-name "${AZURE_BACKUP_STORAGE_ACCOUNT}" \
    --container-name "${AZURE_BACKUP_CONTAINER}" \
    --name "$BLOB_NAME" \
    --file "$LOCAL_PATH" \
    --auth-mode login
fi

log_info "Stopping application processes inside GitLab (keeping DB up)..."
docker exec "$CONTAINER" gitlab-ctl stop puma
docker exec "$CONTAINER" gitlab-ctl stop sidekiq

log_info "Restoring from backup: $BACKUP_TIMESTAMP ..."
docker exec "$CONTAINER" gitlab-backup restore BACKUP="$BACKUP_TIMESTAMP" force=yes

log_info "Restarting GitLab..."
docker exec "$CONTAINER" gitlab-ctl restart

log_info "Restore complete. Run health-check.sh to confirm."
