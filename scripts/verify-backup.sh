#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
set -a; source "$DOCKER_DIR/.env"; set +a

BACKUP_TIER="${1:-}"
if [[ -n "$BACKUP_TIER" && ! "$BACKUP_TIER" =~ ^(daily|weekly|monthly)$ ]]; then
  log_error "Usage: ./verify-backup.sh [daily|weekly|monthly]"
  exit 1
fi

if [[ -n "${AZURE_BACKUP_SAS_TOKEN:-}" ]]; then
  require_command curl
  require_command python3
  SAS_TOKEN="${AZURE_BACKUP_SAS_TOKEN#\?}"
  CONTAINER_URL="https://${AZURE_BACKUP_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_BACKUP_CONTAINER}"
  LIST_FILE="$(mktemp)"
  trap 'rm -f "$LIST_FILE" "${TMP_FILE:-}"' EXIT
  curl --fail-with-body --silent --show-error \
    "${CONTAINER_URL}?restype=container&comp=list&${SAS_TOKEN}" \
    --output "$LIST_FILE"
  LATEST_BLOB="$(python3 - "$LIST_FILE" "$BACKUP_TIER" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
blobs = root.findall("./Blobs/Blob")
prefix = sys.argv[2] + "/" if len(sys.argv) > 2 and sys.argv[2] else ""
blobs = [blob for blob in blobs if blob.findtext("Name", "").startswith(prefix)]
if blobs:
    latest = max(blobs, key=lambda blob: blob.findtext("Properties/Last-Modified", ""))
    print(latest.findtext("Name", ""))
PY
)"
else
  require_command az
  LIST_ARGS=()
  if [[ -n "$BACKUP_TIER" ]]; then
    LIST_ARGS+=(--prefix "$BACKUP_TIER/")
  fi
  LATEST_BLOB="$(az storage blob list \
    --account-name "${AZURE_BACKUP_STORAGE_ACCOUNT}" \
    --container-name "${AZURE_BACKUP_CONTAINER}" \
    "${LIST_ARGS[@]}" \
    --auth-mode login \
    --query "sort_by([], &properties.lastModified)[-1].name" -o tsv)"
fi

if [[ -z "$LATEST_BLOB" ]]; then
  log_error "No backups found in Azure Blob Storage."
  exit 1
fi

log_info "Latest backup found: $LATEST_BLOB"
TMP_FILE="/tmp/$(basename "$LATEST_BLOB")"

if [[ -n "${AZURE_BACKUP_SAS_TOKEN:-}" ]]; then
  curl --fail-with-body --silent --show-error \
    "${CONTAINER_URL}/${LATEST_BLOB}?${SAS_TOKEN}" \
    --output "$TMP_FILE"
else
  az storage blob download \
    --account-name "${AZURE_BACKUP_STORAGE_ACCOUNT}" \
    --container-name "${AZURE_BACKUP_CONTAINER}" \
    --name "$LATEST_BLOB" \
    --file "$TMP_FILE" \
    --auth-mode login
fi

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
