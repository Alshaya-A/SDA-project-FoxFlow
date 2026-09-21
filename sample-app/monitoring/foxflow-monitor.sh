#!/usr/bin/env bash
set -uo pipefail

STATE_DIR="${STATE_DIR:-/var/lib/foxflow-monitor}"
STATE_FILE="$STATE_DIR/state"
GITLAB_HEALTH_URL="${GITLAB_HEALTH_URL:-http://127.0.0.1:8080/users/sign_in}"
APP_HEALTH_URL="${APP_HEALTH_URL:-http://127.0.0.1:3000/health}"
BACKUP_DIR="${BACKUP_DIR:-/srv/foxflow/data/backups}"
DISK_WARN_PERCENT="${DISK_WARN_PERCENT:-75}"
DISK_FAIL_PERCENT="${DISK_FAIL_PERCENT:-90}"
BACKUP_WARN_HOURS="${BACKUP_WARN_HOURS:-26}"
BACKUP_FAIL_HOURS="${BACKUP_FAIL_HOURS:-36}"
GITLAB_CONTAINER="${GITLAB_CONTAINER:-foxflow-gitlab}"
RUNNER_CONTAINER="${RUNNER_CONTAINER:-foxflow-runner}"
APP_CONTAINER="${APP_CONTAINER:-foxflow-app-app-1}"

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is required}"

mkdir -p "$STATE_DIR"

set_check() {
  printf -v "status_$1" '%s' "$2"
  printf -v "detail_$1" '%s' "$3"
}

previous_status() {
  local key="$1"
  if [[ -f "$STATE_FILE" ]]; then
    awk -F= -v wanted="$key" '$1 == wanted { print $2; exit }' "$STATE_FILE"
  fi
}

container_check() {
  local key="$1" container="$2" require_health="$3" running health
  running="$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)"
  if [[ "$running" != "true" ]]; then
    set_check "$key" fail "$container is not running"
    return
  fi
  if [[ "$require_health" == yes ]]; then
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || true)"
    if [[ "$health" != healthy ]]; then
      set_check "$key" fail "$container health=$health"
      return
    fi
  fi
  set_check "$key" ok "$container is running"
}

container_check gitlab "$GITLAB_CONTAINER" yes
container_check runner "$RUNNER_CONTAINER" no
container_check app "$APP_CONTAINER" yes

if curl --fail --silent --show-error --max-time 10 "$GITLAB_HEALTH_URL" >/dev/null 2>&1; then
  set_check gitlab_http ok "GitLab HTTP health passed"
else
  set_check gitlab_http fail "GitLab HTTP health failed"
fi

app_payload="$(curl --fail --silent --show-error --max-time 10 "$APP_HEALTH_URL" 2>/dev/null || true)"
if [[ "$app_payload" == '{"status":"ok","service":"foxflow-sample"}' ]]; then
  set_check app_http ok "Application /health passed"
else
  set_check app_http fail "Application /health returned an unexpected response"
fi

disk_percent="$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"
if (( disk_percent >= DISK_FAIL_PERCENT )); then
  set_check disk fail "Root disk usage is ${disk_percent}%"
elif (( disk_percent >= DISK_WARN_PERCENT )); then
  set_check disk warn "Root disk usage is ${disk_percent}%"
else
  set_check disk ok "Root disk usage is ${disk_percent}%"
fi

latest_backup="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -print0 2>/dev/null | xargs -0 -r ls -1t 2>/dev/null | head -n 1 || true)"
if [[ -z "$latest_backup" ]]; then
  set_check backup fail "No GitLab backup was found"
else
  now="$(date +%s)"
  modified="$(stat -c %Y "$latest_backup" 2>/dev/null || stat -f %m "$latest_backup")"
  backup_age_hours="$(( (now - modified) / 3600 ))"
  if (( backup_age_hours >= BACKUP_FAIL_HOURS )); then
    set_check backup fail "Latest backup is ${backup_age_hours} hours old"
  elif (( backup_age_hours >= BACKUP_WARN_HOURS )); then
    set_check backup warn "Latest backup is ${backup_age_hours} hours old"
  else
    set_check backup ok "Latest backup is ${backup_age_hours} hours old"
  fi
fi

send_telegram() {
  local message="$1"
  curl --fail --silent --show-error --max-time 15 \
    --request POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${message}" \
    >/dev/null
}

message=""
first_run=0
[[ -f "$STATE_FILE" ]] || first_run=1

for key in gitlab runner app gitlab_http app_http disk backup; do
  eval "current=\${status_$key}"
  eval "detail=\${detail_$key}"
  previous="$(previous_status "$key")"
  previous="${previous:-unknown}"
  if [[ "$first_run" -eq 0 && "$current" == "$previous" ]]; then
    continue
  fi
  case "$current" in
    fail) line="🚨 ${key}: ${detail}" ;;
    warn) line="⚠️ ${key}: ${detail}" ;;
    ok)
      if [[ "$previous" == fail || "$previous" == warn ]]; then
        line="✅ ${key}: recovered — ${detail}"
      else
        continue
      fi
      ;;
  esac
  message+="${line}"$'\n'
done

if [[ "$first_run" -eq 1 && -z "$message" ]]; then
  message="✅ FoxFlow proactive monitoring enabled. All checks passed."
elif [[ "$first_run" -eq 1 ]]; then
  message="FoxFlow proactive monitoring enabled with findings:"$'\n'"$message"
fi

if [[ -n "$message" ]]; then
  send_telegram "${message%$'\n'}"
fi

tmp_state="$(mktemp "$STATE_DIR/state.XXXXXX")"
for key in gitlab runner app gitlab_http app_http disk backup; do
  eval "current=\${status_$key}"
  printf '%s=%s\n' "$key" "$current" >> "$tmp_state"
done
chmod 0640 "$tmp_state"
mv "$tmp_state" "$STATE_FILE"
