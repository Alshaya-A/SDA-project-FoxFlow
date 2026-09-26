#!/bin/sh
set -eu

: "${DEPLOY_HOST:?Set DEPLOY_HOST}"
: "${DEPLOY_USER:?Set DEPLOY_USER}"
: "${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN}"
: "${TELEGRAM_CHAT_ID:?Set TELEGRAM_CHAT_ID}"
: "${OPENROUTER_API_KEY:?Set OPENROUTER_API_KEY}"
: "${GITLAB_API_TOKEN:?Set GITLAB_API_TOKEN}"
: "${CI_API_V4_URL:?CI_API_V4_URL is required}"
: "${CI_PROJECT_ID:?CI_PROJECT_ID is required}"

case "$DEPLOY_USER" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid DEPLOY_USER' >&2; exit 1;; esac
printf '%s' "$TELEGRAM_BOT_TOKEN" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]+$' || {
  echo 'Invalid Telegram bot token format' >&2
  exit 1
}
printf '%s' "$TELEGRAM_CHAT_ID" | grep -Eq '^-?[0-9]+$' || {
  echo 'Invalid Telegram chat ID format' >&2
  exit 1
}
printf '%s' "$CI_PROJECT_ID" | grep -Eq '^[0-9]+$' || {
  echo 'Invalid GitLab project ID' >&2
  exit 1
}

remote="${DEPLOY_USER}@${DEPLOY_HOST}"
remote_dir="/tmp/foxflow-copilot-${CI_PIPELINE_ID:-install}"
tmp_env="$(mktemp)"
tmp_service="$(mktemp)"
trap 'rm -f "$tmp_env" "$tmp_service"' EXIT
umask 077

{
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN"
  printf 'TELEGRAM_CHAT_ID=%s\n' "$TELEGRAM_CHAT_ID"
  printf 'OPENROUTER_API_KEY=%s\n' "$OPENROUTER_API_KEY"
  printf 'OPENROUTER_MODEL=%s\n' "${OPENROUTER_MODEL:-openrouter/free}"
  printf 'GITLAB_API_TOKEN=%s\n' "$GITLAB_API_TOKEN"
  printf 'GITLAB_API_URL=%s\n' "$CI_API_V4_URL"
  printf 'GITLAB_PROJECT_ID=%s\n' "$CI_PROJECT_ID"
  printf 'FOXFLOW_PROJECT_URL=%s\n' "${CI_PROJECT_URL:-http://${DEPLOY_HOST}:8080}"
  printf 'APP_HEALTH_URL=http://127.0.0.1:3000/health\n'
  printf 'FOXFLOW_BACKUP_DIR=/srv/foxflow/data/backups\n'
  printf 'FOXFLOW_BACKUP_SCRIPT=/home/%s/SDA-project-FoxFlow/scripts/backup.sh\n' "$DEPLOY_USER"
  if [ -n "${TELEGRAM_ADMIN_USER_IDS:-}" ]; then
    printf 'TELEGRAM_ADMIN_USER_IDS=%s\n' "$TELEGRAM_ADMIN_USER_IDS"
  fi
} > "$tmp_env"

sed "s/__FOXFLOW_USER__/$DEPLOY_USER/g" copilot/foxflow-copilot.service > "$tmp_service"

# The validated deployment values are intentionally expanded by this client.
# shellcheck disable=SC2029
ssh "$remote" "umask 077; mkdir -p '$remote_dir'"
scp copilot/ai-tools.json "$remote:$remote_dir/ai-tools.json"
scp copilot/ai_copilot.py "$remote:$remote_dir/ai_copilot.py"
scp copilot/ai-copilot.sh "$remote:$remote_dir/ai-copilot.sh"
scp "$tmp_service" "$remote:$remote_dir/foxflow-copilot.service"
scp "$tmp_env" "$remote:$remote_dir/copilot.env"

# shellcheck disable=SC2029
ssh "$remote" "
  set -eu
  sudo install -d -o '$DEPLOY_USER' -g '$DEPLOY_USER' -m 0750 /opt/foxflow/copilot
  sudo install -d -o '$DEPLOY_USER' -g '$DEPLOY_USER' -m 0700 /var/lib/foxflow-copilot
  sudo install -d -o root -g root -m 0755 /etc/foxflow
  sudo install -o '$DEPLOY_USER' -g '$DEPLOY_USER' -m 0644 '$remote_dir/ai-tools.json' /opt/foxflow/copilot/ai-tools.json
  sudo install -o '$DEPLOY_USER' -g '$DEPLOY_USER' -m 0755 '$remote_dir/ai_copilot.py' /opt/foxflow/copilot/ai_copilot.py
  sudo install -o '$DEPLOY_USER' -g '$DEPLOY_USER' -m 0755 '$remote_dir/ai-copilot.sh' /opt/foxflow/copilot/ai-copilot.sh
  sudo install -o root -g root -m 0644 '$remote_dir/foxflow-copilot.service' /etc/systemd/system/foxflow-copilot.service
  sudo install -o root -g root -m 0600 '$remote_dir/copilot.env' /etc/foxflow/copilot.env
  sudo systemctl daemon-reload
  sudo systemctl enable --now foxflow-copilot.service
  rm -rf '$remote_dir'
"

echo 'FoxFlow AI DevOps Copilot is installed and active.'
