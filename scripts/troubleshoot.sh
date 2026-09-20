#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CONTAINER="foxflow-gitlab"

echo "===== Container status ====="
docker ps -a --filter "name=$CONTAINER"

echo ""
echo "===== Health status ====="
docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "container not found"

echo ""
echo "===== Last 50 log lines ====="
docker logs --tail 50 "$CONTAINER" 2>&1

echo ""
echo "===== Disk usage on data path ====="
df -h "${FOXFLOW_DATA_PATH:-/srv/foxflow}" 2>/dev/null || echo "path not found"

echo ""
echo "===== GitLab internal service status ====="
docker exec "$CONTAINER" gitlab-ctl status 2>&1 | cat || echo "could not reach gitlab-ctl"
