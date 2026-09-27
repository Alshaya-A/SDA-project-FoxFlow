#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
set -a; source "$DOCKER_DIR/.env"; set +a

CONTAINER="foxflow-gitlab"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_TIER="${1:-daily}"

case "$BACKUP_TIER" in
  daily|weekly|monthly) ;;
  *)
    log_error "Usage: ./backup.sh [daily|weekly|monthly]"
    exit 1
    ;;
esac

log_info "Creating GitLab backup inside container..."
docker exec "$CONTAINER" gitlab-backup create BACKUP="$TIMESTAMP"

BACKUP_DIR="${GITLAB_BACKUP_DIR:-${FOXFLOW_DATA_PATH}/data/backups}"
BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_gitlab_backup.tar"

if [[ ! -f "$BACKUP_FILE" ]]; then
  log_error "Backup file not found at expected path: $BACKUP_FILE"
  exit 1
fi

log_info "Backup created: $BACKUP_FILE"

BLOB_NAME="${BACKUP_TIER}/$(basename "$BACKUP_FILE")"
log_info "Uploading $BACKUP_TIER backup to Azure Blob Storage as $BLOB_NAME..."
if [[ -n "${AZURE_BACKUP_SAS_TOKEN:-}" ]]; then
  require_command curl
  SAS_TOKEN="${AZURE_BACKUP_SAS_TOKEN#\?}"
  BLOB_URL="https://${AZURE_BACKUP_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_BACKUP_CONTAINER}/${BLOB_NAME}?${SAS_TOKEN}"
  curl --fail-with-body --silent --show-error \
    --request PUT \
    --header "x-ms-blob-type: BlockBlob" \
    --upload-file "$BACKUP_FILE" \
    "$BLOB_URL"
else
  require_command az
  az storage blob upload \
    --account-name "${AZURE_BACKUP_STORAGE_ACCOUNT}" \
    --container-name "${AZURE_BACKUP_CONTAINER}" \
    --name "$BLOB_NAME" \
    --file "$BACKUP_FILE" \
    --auth-mode login \
    --overwrite
fi

log_info "Backup uploaded successfully to ${AZURE_BACKUP_STORAGE_ACCOUNT}/${AZURE_BACKUP_CONTAINER}/${BLOB_NAME}"

# Azure holds the long-term weekly and monthly copies. Keep the VM's local
# recovery cache bounded to four days regardless of the remote tier.
find "$BACKUP_DIR" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -mtime +3 -delete
log_info "Removed local backup archives older than four days."
