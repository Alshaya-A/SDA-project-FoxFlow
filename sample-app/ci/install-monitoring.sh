#!/bin/sh
set -eu

: "${DEPLOY_HOST:?Set DEPLOY_HOST}"
: "${DEPLOY_USER:?Set DEPLOY_USER}"
: "${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN}"
: "${TELEGRAM_CHAT_ID:?Set TELEGRAM_CHAT_ID}"

printf '%s' "$TELEGRAM_BOT_TOKEN" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]+$' || {
  echo 'Invalid Telegram bot token format' >&2
  exit 1
}
printf '%s' "$TELEGRAM_CHAT_ID" | grep -Eq '^-?[0-9]+$' || {
  echo 'Invalid Telegram chat ID format' >&2
  exit 1
}

remote="${DEPLOY_USER}@${DEPLOY_HOST}"
remote_dir="/tmp/foxflow-monitor-${CI_PIPELINE_ID:-install}"
tmp_env="$(mktemp)"
trap 'rm -f "$tmp_env"' EXIT
umask 077
{
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN"
  printf 'TELEGRAM_CHAT_ID=%s\n' "$TELEGRAM_CHAT_ID"
  printf 'GITLAB_HEALTH_URL=http://127.0.0.1:8080/users/sign_in\n'
  printf 'APP_HEALTH_URL=http://127.0.0.1:3000/health\n'
  printf 'BACKUP_DIR=/srv/foxflow/data/backups\n'
} > "$tmp_env"

ssh "$remote" "umask 077; mkdir -p '$remote_dir'"
scp monitoring/foxflow-monitor.sh "$remote:$remote_dir/foxflow-monitor"
scp monitoring/foxflow-monitor.service "$remote:$remote_dir/foxflow-monitor.service"
scp monitoring/foxflow-monitor.timer "$remote:$remote_dir/foxflow-monitor.timer"
scp "$tmp_env" "$remote:$remote_dir/foxflow-monitor.env"

ssh "$remote" "
  set -eu
  sudo install -m 0755 '$remote_dir/foxflow-monitor' /usr/local/sbin/foxflow-monitor
  sudo install -m 0644 '$remote_dir/foxflow-monitor.service' /etc/systemd/system/foxflow-monitor.service
  sudo install -m 0644 '$remote_dir/foxflow-monitor.timer' /etc/systemd/system/foxflow-monitor.timer
  sudo install -m 0600 '$remote_dir/foxflow-monitor.env' /etc/foxflow-monitor.env
  sudo mkdir -p -m 0750 /var/lib/foxflow-monitor
  sudo systemctl daemon-reload
  sudo systemctl enable --now foxflow-monitor.timer
  sudo systemctl start foxflow-monitor.service
  rm -rf '$remote_dir'
"

echo 'FoxFlow proactive monitoring is installed and active.'
