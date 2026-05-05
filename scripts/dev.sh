#!/usr/bin/env bash
# scripts/dev.sh — manage all 8 Node services in background mode
#
# Usage:
#   ./scripts/dev.sh start    — start Redis + all services, then health-check
#   ./scripts/dev.sh stop     — kill all service processes + Redis
#   ./scripts/dev.sh status   — print health of every service
#   ./scripts/dev.sh restart  — stop then start
#
# Logs are written to /tmp/<name>.log

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="/tmp"

declare -A SERVICES=(
  [gateway]="3000"
  [auth]="3001"
  [user]="3002"
  [trip]="3003"
  [booking]="3004"
  [payment]="3005"
  [notification]="3006"
  [cost]="3009"
)

# Colour helpers (safe fallback if tput unavailable)
_bold=""  _reset=""  _green=""  _red=""  _yellow=""  _cyan=""
if command -v tput &>/dev/null && tput colors &>/dev/null; then
  _bold=$(tput bold)
  _reset=$(tput sgr0)
  _green=$(tput setaf 2)
  _red=$(tput setaf 1)
  _yellow=$(tput setaf 3)
  _cyan=$(tput setaf 6)
fi

info()    { echo "${_cyan}${_bold}[dev]${_reset} $*"; }
success() { echo "${_green}${_bold}[dev]${_reset} $*"; }
warn()    { echo "${_yellow}${_bold}[dev]${_reset} $*"; }
error()   { echo "${_red}${_bold}[dev]${_reset} $*" >&2; }

# ── start ────────────────────────────────────────────────────────────────────

cmd_start() {
  cd "$REPO_ROOT"

  # 1. Redis
  info "Starting Redis via Docker Compose…"
  docker compose up -d
  info "Redis ready."

  # 2. Each Node service
  for name in gateway auth user trip booking payment notification cost; do
    local log="$LOG_DIR/${name}.log"
    local script="dev:${name}"
    # 'cost' npm script is dev:cost but service is named 'cost' in our map
    info "Starting ${name}-service → $log"
    (cd "$REPO_ROOT" && npm run "${script}" >> "$log" 2>&1) &
    echo $! > "$LOG_DIR/${name}.pid"
  done

  info "Waiting 5 s for services to boot…"
  sleep 5

  cmd_status
}

# ── stop ─────────────────────────────────────────────────────────────────────

cmd_stop() {
  info "Stopping Node services…"
  pkill -f ts-node-dev 2>/dev/null || true
  pkill -f "node.*dist/server" 2>/dev/null || true

  # Clean up pid files
  for name in gateway auth user trip booking payment notification cost; do
    local pidfile="$LOG_DIR/${name}.pid"
    if [[ -f "$pidfile" ]]; then
      local pid
      pid=$(cat "$pidfile")
      kill "$pid" 2>/dev/null || true
      rm -f "$pidfile"
    fi
  done

  info "Stopping Redis…"
  cd "$REPO_ROOT" && docker compose down
  success "All services stopped."
}

# ── status ────────────────────────────────────────────────────────────────────

cmd_status() {
  echo ""
  printf "%-22s %-6s %s\n" "Service" "Port" "Status"
  printf "%-22s %-6s %s\n" "-------" "----" "------"

  declare -A NAMES=(
    [gateway]="API Gateway"
    [auth]="Auth Service"
    [user]="User Service"
    [trip]="Trip Service"
    [booking]="Booking Service"
    [payment]="Payment Service"
    [notification]="Notification Service"
    [cost]="Cost Calculation"
  )

  for name in gateway auth user trip booking payment notification cost; do
    local port="${SERVICES[$name]}"
    local label="${NAMES[$name]}"

    if curl -sf "http://localhost:${port}/health" &>/dev/null; then
      printf "%-22s %-6s %s\n" "$label" "$port" "${_green}● running${_reset}"
    else
      printf "%-22s %-6s %s\n" "$label" "$port" "${_red}○ offline${_reset}"
    fi
  done

  echo ""
  # Redis
  if docker compose ps 2>/dev/null | grep -q "running"; then
    printf "%-22s %-6s %s\n" "Redis" "6379" "${_green}● running${_reset}"
  else
    printf "%-22s %-6s %s\n" "Redis" "6379" "${_red}○ offline${_reset}"
  fi
  echo ""
}

# ── restart ───────────────────────────────────────────────────────────────────

cmd_restart() {
  cmd_stop
  sleep 2
  cmd_start
}

# ── dispatch ──────────────────────────────────────────────────────────────────

case "${1:-}" in
  start)   cmd_start   ;;
  stop)    cmd_stop    ;;
  status)  cmd_status  ;;
  restart) cmd_restart ;;
  *)
    echo "Usage: $0 {start|stop|status|restart}"
    exit 1
    ;;
esac
