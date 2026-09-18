#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if command -v az >/dev/null 2>&1; then
  log_info "Azure CLI already installed: $(az --version | head -n1)"
  exit 0
fi

log_info "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
log_info "Azure CLI installed. Run 'az login' (or use a managed identity on the VM) before using backup.sh."
az --version | head -n1
