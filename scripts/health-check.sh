#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CONTAINER="foxflow-gitlab"

RUNNING="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo "false")"
if [[ "$RUNNING" != "true" ]]; then
  log_error "$CONTAINER is not running."
  exit 1
fi

STATUS="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER")"
log_info "Container health status: $STATUS"

if [[ "$STATUS" != "healthy" ]]; then
  log_error "GitLab is not healthy yet (status: $STATUS)."
  exit 1
fi

log_info "All checks passed. GitLab is fully operational."
