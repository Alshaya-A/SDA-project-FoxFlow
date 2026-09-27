#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

LOG_FILE="${SCRIPT_DIR}/../backup.log"
DAILY_CRON="0 */6 * * * ${SCRIPT_DIR}/backup.sh daily >> ${LOG_FILE} 2>&1"
WEEKLY_CRON="15 3 * * 0 ${SCRIPT_DIR}/backup.sh weekly >> ${LOG_FILE} 2>&1"
MONTHLY_CRON="30 3 1 * * ${SCRIPT_DIR}/backup.sh monthly >> ${LOG_FILE} 2>&1"
EXISTING_CRONTAB="$(crontab -l 2>/dev/null || true)"

{
  printf '%s\n' "$EXISTING_CRONTAB" | grep -v "backup.sh" || true
  echo "$DAILY_CRON"
  echo "$WEEKLY_CRON"
  echo "$MONTHLY_CRON"
} | crontab -

log_info "Backup cron jobs installed: every 6 hours, weekly on Sunday, and monthly on day 1."
crontab -l | grep backup.sh
