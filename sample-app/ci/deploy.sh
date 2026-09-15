#!/bin/sh
set -eu
: "${DEPLOY_HOST:?Set DEPLOY_HOST}"
: "${DEPLOY_USER:?Set DEPLOY_USER}"
: "${SSH_PRIVATE_KEY:?Set a GitLab File variable}"
: "${SSH_KNOWN_HOSTS:?Set a verified GitLab File variable}"
: "${CI_REGISTRY:?}"
: "${CI_REGISTRY_USER:?}"
: "${CI_REGISTRY_PASSWORD:?}"
: "${IMAGE_TAG:?}"
case "$DEPLOY_USER" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid DEPLOY_USER' >&2; exit 1;; esac
case "$DEPLOY_HOST" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Use an IPv4 address or DNS hostname' >&2; exit 1;; esac
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
cp "$SSH_PRIVATE_KEY" "$HOME/.ssh/id_ed25519"
cp "$SSH_KNOWN_HOSTS" "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/id_ed25519" "$HOME/.ssh/known_hosts"
printf 'Host *\n  BatchMode yes\n  StrictHostKeyChecking yes\n  ConnectTimeout 15\n' > "$HOME/.ssh/config"
export DOCKER_HOST="ssh://${DEPLOY_USER}@${DEPLOY_HOST}"
unset DOCKER_TLS_VERIFY DOCKER_CERT_PATH DOCKER_TLS_CERTDIR
# Credentials are held in the ephemeral CI client, not persisted on the target VM.
printf '%s' "$CI_REGISTRY_PASSWORD" | docker login "$CI_REGISTRY" -u "$CI_REGISTRY_USER" --password-stdin
trap 'docker logout "$CI_REGISTRY" >/dev/null 2>&1 || true' EXIT
docker compose -p foxflow-app -f deploy/docker-compose.yml config --quiet
docker compose -p foxflow-app -f deploy/docker-compose.yml pull
docker compose -p foxflow-app -f deploy/docker-compose.yml up -d --wait --wait-timeout 120
