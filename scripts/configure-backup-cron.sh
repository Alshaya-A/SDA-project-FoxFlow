#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CRON_LINE="0 3 * * * ${SCRIPT_DIR}/backup.sh >> ${SCRIPT_DIR}/../backup.log 2>&1"

( crontab -l 2>/dev/null | grep -v "backup.sh" ; echo "$CRON_LINE" ) | crontab -

log_info "Cron job installed: daily backup at 03:00."
crontab -l | grep backup.sh
