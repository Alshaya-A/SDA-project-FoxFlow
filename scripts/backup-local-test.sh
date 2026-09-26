#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
set -a; source "$DOCKER_DIR/.env"; set +a

CONTAINER="foxflow-gitlab"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log_info "Creating GitLab backup inside container..."
docker exec "$CONTAINER" gitlab-backup create BACKUP="$TIMESTAMP"

BACKUP_FILE="/var/opt/gitlab/backups/${TIMESTAMP}_gitlab_backup.tar"

if ! docker exec "$CONTAINER" test -f "$BACKUP_FILE"; then
  log_error "Backup file not found at expected path: $BACKUP_FILE"
  exit 1
fi

log_info "Backup created successfully: $BACKUP_FILE"
docker exec "$CONTAINER" ls -lh "$BACKUP_FILE"
