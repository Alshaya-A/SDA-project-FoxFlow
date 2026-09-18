#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"

echo "==> Checking .env file..."
if [[ ! -f "$DOCKER_DIR/.env" ]]; then
  echo "ERROR: .env not found at $DOCKER_DIR/.env"
  echo "Run: cp .env.example .env  and edit values first."
  exit 1
fi

echo "==> Starting GitLab via Docker Compose..."
cd "$DOCKER_DIR"
docker compose up -d

echo "==> Waiting for GitLab to become healthy (this can take a few minutes)..."
ATTEMPTS=0
MAX_ATTEMPTS=60
until [[ "$(docker inspect -f '{{.State.Health.Status}}' foxflow-gitlab 2>/dev/null)" == "healthy" ]]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo "ERROR: GitLab did not become healthy in time."
    exit 1
  fi
  echo "   still waiting... ($ATTEMPTS/$MAX_ATTEMPTS)"
  sleep 10
done

echo "==> GitLab is healthy and ready."
