#!/bin/sh
# Root helper for the unprivileged Copilot service. Every operation and target
# is explicitly enumerated; user text and model output never become shell code.
set -eu

operation="${1:-}"
[ "$#" -gt 0 ] && shift

container_for() {
  case "$1" in
    gitlab) printf '%s\n' foxflow-gitlab ;;
    app) printf '%s\n' foxflow-app-app-1 ;;
    runner) printf '%s\n' foxflow-runner ;;
    *) echo 'Unsupported service' >&2; exit 2 ;;
  esac
}

case "$operation" in
  container-status)
    [ "$#" -eq 1 ] || exit 2
    container="$(container_for "$1")"
    exec docker inspect -f '{{.State.Running}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container"
    ;;
  logs)
    [ "$#" -eq 1 ] || exit 2
    container="$(container_for "$1")"
    exec docker logs --tail 50 "$container"
    ;;
  restart)
    [ "$#" -eq 1 ] || exit 2
    container="$(container_for "$1")"
    exec docker restart "$container"
    ;;
  backup)
    [ "$#" -eq 0 ] || exit 2
    exec /home/__FOXFLOW_USER__/SDA-project-FoxFlow/scripts/backup.sh
    ;;
  backup-status)
    [ "$#" -eq 0 ] || exit 2
    backup_dir=/srv/foxflow/data/backups
    latest="$(find "$backup_dir" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -print0 2>/dev/null | xargs -0 -r ls -1t 2>/dev/null | head -n 1 || true)"
    if [ -z "$latest" ]; then
      echo none
      exit 0
    fi
    modified="$(stat -c %Y "$latest")"
    size="$(stat -c %s "$latest")"
    printf '%s|%s\n' "$modified" "$size"
    ;;
  *)
    echo 'Unsupported operation' >&2
    exit 2
    ;;
esac
