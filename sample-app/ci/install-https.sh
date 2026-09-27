#!/bin/sh
set -eu

: "${DEPLOY_HOST:?Set DEPLOY_HOST}"
: "${DEPLOY_USER:?Set DEPLOY_USER}"

case "$DEPLOY_USER" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid DEPLOY_USER' >&2; exit 1;; esac
case "$DEPLOY_HOST" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Use an IPv4 address or DNS hostname' >&2; exit 1;; esac

default_host="foxflow.$(printf '%s' "$DEPLOY_HOST" | tr '.' '-').sslip.io"
https_host="${HTTPS_HOST:-$default_host}"
case "$https_host" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Invalid HTTPS_HOST' >&2; exit 1;; esac
default_alt_host="foxflow.$(printf '%s' "$DEPLOY_HOST" | tr '.' '-').nip.io"
https_alt_host="${HTTPS_ALT_HOST:-$default_alt_host}"
case "$https_alt_host" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Invalid HTTPS_ALT_HOST' >&2; exit 1;; esac
default_gitlab_host="gitlab.$(printf '%s' "$DEPLOY_HOST" | tr '.' '-').sslip.io"
gitlab_https_host="${GITLAB_HTTPS_HOST:-$default_gitlab_host}"
case "$gitlab_https_host" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Invalid GITLAB_HTTPS_HOST' >&2; exit 1;; esac
default_gitlab_alt_host="gitlab.$(printf '%s' "$DEPLOY_HOST" | tr '.' '-').nip.io"
gitlab_https_alt_host="${GITLAB_HTTPS_ALT_HOST:-$default_gitlab_alt_host}"
case "$gitlab_https_alt_host" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Invalid GITLAB_HTTPS_ALT_HOST' >&2; exit 1;; esac

remote="${DEPLOY_USER}@${DEPLOY_HOST}"
remote_dir="/tmp/foxflow-https-${CI_PIPELINE_ID:-install}"

# The validated deployment values are intentionally expanded by this client.
# shellcheck disable=SC2029
ssh "$remote" "umask 077; mkdir -p '$remote_dir'"
scp https/Caddyfile "$remote:$remote_dir/Caddyfile"

# Run Caddy separately from the application so ordinary application deploys do
# not replace its certificate state. Only the Caddyfile is mounted read-only.
# shellcheck disable=SC2029
ssh "$remote" "
  set -eu
  sudo install -d -o root -g root -m 0755 /srv/foxflow/https
  sudo install -o root -g root -m 0644 '$remote_dir/Caddyfile' /srv/foxflow/https/Caddyfile
  docker pull caddy:2-alpine
  docker rm -f foxflow-https >/dev/null 2>&1 || true
  docker run -d \
    --name foxflow-https \
    --restart unless-stopped \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --cap-add NET_BIND_SERVICE \
    --add-host host.docker.internal:host-gateway \
    -e FOXFLOW_HTTPS_HOST='$https_host' \
    -e FOXFLOW_HTTPS_ALT_HOST='$https_alt_host' \
    -e GITLAB_HTTPS_HOST='$gitlab_https_host' \
    -e GITLAB_HTTPS_ALT_HOST='$gitlab_https_alt_host' \
    -p 80:80 \
    -p 443:443 \
    -v /srv/foxflow/https/Caddyfile:/etc/caddy/Caddyfile:ro \
    -v foxflow-caddy-data:/data \
    -v foxflow-caddy-config:/config \
    caddy:2-alpine
  docker exec foxflow-https caddy validate --config /etc/caddy/Caddyfile
  rm -rf '$remote_dir'
"

echo "FoxFlow HTTPS proxy installed for https://$https_host"
echo "FoxFlow alternate HTTPS proxy installed for https://$https_alt_host"
echo "GitLab HTTPS proxy installed for https://$gitlab_https_host"
echo "GitLab alternate HTTPS proxy installed for https://$gitlab_https_alt_host"
