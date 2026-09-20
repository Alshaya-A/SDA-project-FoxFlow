#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_env_file "$DOCKER_DIR/.env"

cd "$DOCKER_DIR"

log_info "Pulling latest image (per GITLAB_VERSION in .env)..."
docker compose pull

log_info "Recreating container with new image..."
docker compose up -d

wait_for_healthy "foxflow-gitlab" 60
log_info "Redeploy complete."
