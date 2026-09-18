#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
source "$SCRIPT_DIR/lib.sh"
set -a; source "$DOCKER_DIR/.env"; set +a

if [[ -z "${GITLAB_RUNNER_TOKEN:-}" ]]; then
  log_error "GITLAB_RUNNER_TOKEN not set in .env. Get it from Admin Area > CI/CD > Runners."
  exit 1
fi

GITLAB_URL="http://${GITLAB_HOSTNAME}:${GITLAB_HTTP_PORT}"
log_info "Registering GitLab Runner against ${GITLAB_URL}..."

docker run --rm -v "${FOXFLOW_DATA_PATH}/gitlab-runner/config:/etc/gitlab-runner" \
  --network host \
  gitlab/gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --token "${GITLAB_RUNNER_TOKEN}" \
  --executor "docker" \
  --docker-image "docker:24-dind" \
  --description "foxflow-runner"

log_info "Runner registered."
