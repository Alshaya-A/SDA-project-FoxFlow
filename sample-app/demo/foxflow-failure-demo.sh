#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  exec sudo "$0" "$@"
fi

action="${1:-status}"
container="foxflow-failure-demo"
port="3001"
state_dir="/var/lib/foxflow-demo-monitor"
monitor="/usr/local/sbin/foxflow-monitor"
secrets="/etc/foxflow-monitor.env"
production_container="foxflow-app-app-1"
health_command="node -e \"fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""

require_runtime() {
  command -v docker >/dev/null
  [[ -x "$monitor" ]] || { echo "Monitoring is not installed: $monitor" >&2; exit 1; }
  [[ -r "$secrets" ]] || { echo "Telegram configuration is not installed: $secrets" >&2; exit 1; }
  docker inspect "$production_container" >/dev/null 2>&1 || {
    echo "Production container is unavailable: $production_container" >&2
    exit 1
  }
}

prepare_state() {
  install -d -m 0750 "$state_dir"
  if [[ ! -f "$state_dir/state" ]]; then
    printf '%s\n' \
      'gitlab=ok' \
      'runner=ok' \
      'app=ok' \
      'gitlab_http=ok' \
      'app_http=ok' \
      'disk=ok' \
      'backup=ok' > "$state_dir/state"
    chmod 0640 "$state_dir/state"
  fi
}

run_demo_container() {
  local failure_mode="$1" image expected health
  image="$(docker inspect -f '{{.Config.Image}}' "$production_container")"
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker run -d \
    --name "$container" \
    --restart no \
    --publish "127.0.0.1:${port}:3000" \
    --env "FOXFLOW_DEMO_FAIL=${failure_mode}" \
    --health-cmd "$health_command" \
    --health-interval 2s \
    --health-timeout 2s \
    --health-retries 1 \
    --health-start-period 2s \
    "$image" >/dev/null

  expected=healthy
  [[ "$failure_mode" == true ]] && expected=unhealthy
  for _ in {1..20}; do
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container")"
    [[ "$health" == "$expected" ]] && return
    sleep 1
  done
  echo "Demo container did not become $expected" >&2
  exit 1
}

run_monitor() {
  set -a
  # shellcheck disable=SC1090
  source "$secrets"
  set +a
  STATE_DIR="$state_dir" \
  APP_CONTAINER="$container" \
  APP_HEALTH_URL="http://127.0.0.1:${port}/health" \
    "$monitor"
}

show_status() {
  if ! docker inspect "$container" >/dev/null 2>&1; then
    echo 'Demo container is not running.'
    return
  fi
  docker ps --filter "name=^/${container}$" --format 'container={{.Names}} status={{.Status}} ports={{.Ports}}'
  curl --silent --show-error --max-time 5 \
    --write-out '\nhttp_status=%{http_code}\n' \
    "http://127.0.0.1:${port}/health" || true
}

case "$action" in
  fail)
    require_runtime
    prepare_state
    run_demo_container true
    run_monitor
    echo 'Official failure alert sent. Production remains available on port 3000.'
    show_status
    ;;
  recover)
    require_runtime
    prepare_state
    run_demo_container false
    run_monitor
    echo 'Official recovery alert sent.'
    show_status
    ;;
  status)
    show_status
    ;;
  cleanup)
    docker rm -f "$container" >/dev/null 2>&1 || true
    rm -rf "$state_dir"
    echo 'Failure demo removed.'
    ;;
  *)
    echo "Usage: $0 {fail|recover|status|cleanup}" >&2
    exit 2
    ;;
esac
