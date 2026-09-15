#!/usr/bin/env bash
# Exercise production Compose health gating with a disposable local fixture.
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Explicitly target Docker Desktop, never an inherited remote DOCKER_HOST.
context=${LOCAL_DOCKER_CONTEXT:-desktop-linux}
endpoint=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')
case "$endpoint" in unix://*) ;; *) echo 'Test requires a local Unix Docker socket.' >&2; exit 1;; esac
export FIXTURE_DIR="$repo_dir/tests/deploy-fixture"
export IMAGE_TAG=node:24-alpine
export APP_PORT=127.0.0.1:0
export HEALTH_MODE=healthy
project="foxflow-member4-test-$(date +%s)-$$"
compose() {
  docker --context "$context" compose -p "$project" \
    -f "$repo_dir/sample-app/deploy/docker-compose.yml" \
    -f "$FIXTURE_DIR/compose.test.yml" "$@"
}
cleanup() { compose down --timeout 5; }
trap cleanup EXIT
compose config --quiet
compose pull
compose up -d --wait --wait-timeout 30
address=$(compose port app 3000)
body=$(curl --fail --silent --show-error --max-time 5 "http://$address/health")
printf '%s' "$body" | jq -e '.status == "ok" and .fixture == true' >/dev/null
printf 'PASS: healthy application accepted; HTTP 200 and valid JSON: %s\n' "$body"
for mode in http-error invalid-json; do
  export HEALTH_MODE="$mode"
  if compose up -d --force-recreate --wait --wait-timeout 30; then
    echo "FAIL: $mode was accepted" >&2
    exit 1
  fi
  container=$(compose ps -aq app)
  status=$(docker --context "$context" inspect --format '{{.State.Health.Status}}' "$container")
  [[ "$status" == unhealthy ]] || { echo "Unexpected failure: $status" >&2; exit 1; }
  printf 'PASS: %s rejected by production health probe\n' "$mode"
done
