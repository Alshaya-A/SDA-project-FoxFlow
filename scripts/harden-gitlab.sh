#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CONTAINER="foxflow-gitlab"

log_info "Disabling public sign-up..."
docker exec "$CONTAINER" gitlab-rails runner \
  "settings = ApplicationSetting.current; settings.update!(signup_enabled: false)"

log_info "Enforcing Two-Factor Authentication for all users (grace period: 2 days)..."
docker exec "$CONTAINER" gitlab-rails runner \
  "settings = ApplicationSetting.current; settings.update!(require_two_factor_authentication: true, two_factor_grace_period: 48)"

log_info "Restricting new project visibility to private by default..."
docker exec "$CONTAINER" gitlab-rails runner \
  "settings = ApplicationSetting.current; settings.update!(default_project_visibility: 0)"

log_info "Hardening steps applied. Verify manually under Admin Area > Settings."
