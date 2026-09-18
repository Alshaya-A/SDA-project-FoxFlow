#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
set -a; source "$DOCKER_DIR/.env"; set +a

require_command az

LATEST_BLOB="$(az storage blob list \
  --account-name "${AZURE_BACKUP_STORAGE_ACCOUNT}" \
  --container-name "${AZURE_BACKUP_CONTAINER}" \
  --auth-mode login \
  --query "sort_by([], &properties.lastModified)[-1].name" -o tsv)"

if [[ -z "$LATEST_BLOB" ]]; then
  log_error "No backups found in Azure Blob Storage."
  exit 1
fi

log_info "Latest backup found: $LATEST_BLOB"
TMP_FILE="/tmp/${LATEST_BLOB}"

az storage blob download \
  --account-name "${AZURE_BACKUP_STORAGE_ACCOUNT}" \
  --container-name "${AZURE_BACKUP_CONTAINER}" \
  --name "$LATEST_BLOB" \
  --file "$TMP_FILE" \
  --auth-mode login

log_info "Verifying tar archive integrity..."
if tar -tf "$TMP_FILE" > /dev/null 2>&1; then
  log_info "Backup archive is valid and readable."
else
  log_error "Backup archive appears CORRUPTED."
  rm -f "$TMP_FILE"
  exit 1
fi

rm -f "$TMP_FILE"
log_info "Verification complete. Backup is trustworthy."
