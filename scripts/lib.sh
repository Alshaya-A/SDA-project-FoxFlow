#!/usr/bin/env bash
# Shared functions - sourced by other scripts, not run directly

log_info()  { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Required command not found: $1"
    exit 1
  fi
}

require_env_file() {
  local env_path="$1"
  if [[ ! -f "$env_path" ]]; then
    log_error ".env not found at $env_path (run: cp .env.example .env)"
    exit 1
  fi
}

wait_for_healthy() {
  local container="$1"
  local max_attempts="${2:-60}"
  local attempt=0
  until [[ "$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)" == "healthy" ]]; do
    attempt=$((attempt + 1))
    if [[ $attempt -ge $max_attempts ]]; then
      log_error "$container did not become healthy in time."
      return 1
    fi
    log_info "waiting for $container... ($attempt/$max_attempts)"
    sleep 10
  done
  log_info "$container is healthy."
}
