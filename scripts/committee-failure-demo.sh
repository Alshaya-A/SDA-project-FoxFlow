#!/usr/bin/env bash
set -euo pipefail

action="${1:-status}"
host="${FOXFLOW_DEMO_HOST:-20.127.65.116}"
user="${FOXFLOW_DEMO_USER:-azureuser}"
key="${FOXFLOW_DEMO_KEY:-$HOME/.ssh/foxflow}"

case "$action" in
  fail|recover|status|cleanup) ;;
  *)
    echo "Usage: $0 {fail|recover|status|cleanup}" >&2
    exit 2
    ;;
esac
case "$host" in ''|-*|*[!a-zA-Z0-9.-]*) echo 'Invalid FOXFLOW_DEMO_HOST' >&2; exit 2;; esac
case "$user" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid FOXFLOW_DEMO_USER' >&2; exit 2;; esac
[[ -r "$key" ]] || { echo "SSH key not found: $key" >&2; exit 1; }

ssh -i "$key" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
  "${user}@${host}" "sudo foxflow-failure-demo '$action'"
