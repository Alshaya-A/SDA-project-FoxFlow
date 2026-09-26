#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_env_file "$DOCKER_DIR/.env"
set -a; source "$DOCKER_DIR/.env"; set +a

: "${GITLAB_HOSTNAME:?GITLAB_HOSTNAME must be set in docker/.env}"
: "${GITLAB_HTTP_PORT:?GITLAB_HTTP_PORT must be set in docker/.env}"
: "${GITLAB_SSH_PORT:?GITLAB_SSH_PORT must be set in docker/.env}"
: "${FOXFLOW_DATA_PATH:?FOXFLOW_DATA_PATH must be set in docker/.env}"

GITLAB_EXTERNAL_URL="${GITLAB_EXTERNAL_URL:-http://${GITLAB_HOSTNAME}:${GITLAB_HTTP_PORT}}"
case "$GITLAB_EXTERNAL_URL" in
  http://*|https://*) ;;
  *) echo 'GITLAB_EXTERNAL_URL must start with http:// or https://' >&2; exit 1;;
esac
case "$GITLAB_EXTERNAL_URL" in *[!a-zA-Z0-9.:/_-]*) echo 'Invalid GITLAB_EXTERNAL_URL' >&2; exit 1;; esac
export GITLAB_EXTERNAL_URL

REGISTRY_PORT="${GITLAB_REGISTRY_PORT:-5050}"
GITLAB_REGISTRY_HOST="${GITLAB_REGISTRY_HOST:-$GITLAB_HOSTNAME}"
case "$GITLAB_REGISTRY_HOST" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Invalid GITLAB_REGISTRY_HOST' >&2; exit 1;; esac
OVERRIDE_FILE="$DOCKER_DIR/docker-compose.override.yml"

install -d -m 0755 \
  "$FOXFLOW_DATA_PATH/config" \
  "$FOXFLOW_DATA_PATH/logs" \
  "$FOXFLOW_DATA_PATH/data"

cat > "$OVERRIDE_FILE" <<'YAML'
services:
  gitlab:
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url '${GITLAB_EXTERNAL_URL}'
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
        gitlab_rails['gitlab_shell_ssh_port'] = ${GITLAB_SSH_PORT}
        registry_external_url 'http://${GITLAB_REGISTRY_HOST}:${GITLAB_REGISTRY_PORT:-5050}'
        registry_nginx['listen_port'] = ${GITLAB_REGISTRY_PORT:-5050}
        registry_nginx['listen_https'] = false
    ports:
      - "${GITLAB_REGISTRY_PORT:-5050}:${GITLAB_REGISTRY_PORT:-5050}"
    volumes:
      - ${FOXFLOW_DATA_PATH}/config:/etc/gitlab
      - ${FOXFLOW_DATA_PATH}/logs:/var/log/gitlab
      - ${FOXFLOW_DATA_PATH}/data:/var/opt/gitlab
YAML

chmod 0644 "$OVERRIDE_FILE"
(cd "$DOCKER_DIR" && docker compose config --quiet)

log_info "Azure GitLab override written to $OVERRIDE_FILE."
log_info "GitLab external URL: ${GITLAB_EXTERNAL_URL}"
log_info "Registry endpoint: http://${GITLAB_REGISTRY_HOST}:${REGISTRY_PORT}"
log_info "Run ./scripts/deploy.sh to apply the configuration."
