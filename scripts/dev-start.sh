#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# LessGo — Local Development Launcher
# ═══════════════════════════════════════════════════════════════════════════════
#
# Starts ALL backend services (Node.js + Python) in the background with
# color-coded log streaming. Includes health checks and graceful shutdown.
#
# USAGE
#   ./scripts/dev-start.sh          Start everything
#   ./scripts/dev-start.sh stop     Kill all LessGo services
#   ./scripts/dev-start.sh logs     Tail all log files
#   ./scripts/dev-start.sh status   Health check all services
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/.dev-logs"
PID_FILE="$LOG_DIR/.pids"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Service Definitions ──────────────────────────────────────────────────────
# Format: "NAME|PORT|TYPE|PATH|COMMAND"
# TYPE: node or python
SERVICES=(
  "Auth Service|3001|node|services/auth-service|npm run dev"
  "User Service|3002|node|services/user-service|npm run dev"
  "Trip Service|3003|node|services/trip-service|npm run dev"
  "Booking Service|3004|node|services/booking-service|npm run dev"
  "Payment Service|3005|node|services/payment-service|npm run dev"
  "Notification Service|3006|node|services/notification-service|npm run dev"
  "Cost Service|3009|node|services/cost-calculation-service|npm run dev"
  "Safety Service|8005|node|services/safety-service|npm run dev"
  "Routing Service|8002|python|services/routing-service|python -m app.main"
  "Embedding Service|3010|python|services/embedding-service|python -m app.main"
  "API Gateway|3000|node|services/api-gateway|npm run dev"
)

# ── Helpers ───────────────────────────────────────────────────────────────────
banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}LessGo — Local Development Environment${NC}                    ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

log_name() {
  local name="$1"
  echo "$name" | tr '[:upper:] ' '[:lower:]-' | sed 's/-$//'
}

health_check() {
  local name="$1"
  local port="$2"
  local url="http://127.0.0.1:${port}/health"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo "000")
  if [[ "$status" == "200" ]]; then
    printf "  ${GREEN}✓${NC} %-24s ${DIM}:${port}${NC}\n" "$name"
    return 0
  else
    printf "  ${RED}✗${NC} %-24s ${DIM}:${port} (HTTP ${status})${NC}\n" "$name"
    return 1
  fi
}

# ── Stop Command ──────────────────────────────────────────────────────────────
do_stop() {
  echo -e "${YELLOW}Stopping all LessGo services...${NC}"
  
  # Kill tracked PIDs
  if [[ -f "$PID_FILE" ]]; then
    while IFS= read -r pid; do
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  fi

  # Kill any remaining processes by pattern
  pkill -f "ts-node-dev.*services/" 2>/dev/null || true
  pkill -f "dotenv.*ts-node-dev" 2>/dev/null || true
  pkill -f "python.*app/main.py" 2>/dev/null || true
  pkill -f "uvicorn.*app.main" 2>/dev/null || true
  
  sleep 1
  echo -e "${GREEN}✓ All services stopped${NC}"
}

# ── Status Command ────────────────────────────────────────────────────────────
do_status() {
  banner
  echo -e "${BOLD}  Service Health Check${NC}"
  echo -e "  ${DIM}────────────────────────────────────${NC}"
  
  local total=0
  local up=0
  
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port type path cmd <<< "$entry"
    total=$((total + 1))
    if health_check "$name" "$port"; then
      up=$((up + 1))
    fi
  done
  
  echo ""
  if [[ $up -eq $total ]]; then
    echo -e "  ${GREEN}${BOLD}All ${total} services are healthy ✓${NC}"
  else
    echo -e "  ${YELLOW}${up}/${total} services are running${NC}"
  fi
  echo ""
}

# ── Logs Command ──────────────────────────────────────────────────────────────
do_logs() {
  if [[ ! -d "$LOG_DIR" ]]; then
    echo -e "${RED}No log directory found. Start services first.${NC}"
    exit 1
  fi
  echo -e "${CYAN}Tailing all logs (Ctrl+C to stop)...${NC}"
  tail -f "$LOG_DIR"/*.log 2>/dev/null
}

# ── Start Command ─────────────────────────────────────────────────────────────
do_start() {
  banner
  
  # Stop any existing services
  echo -e "${DIM}Cleaning up previous sessions...${NC}"
  do_stop 2>/dev/null || true
  echo ""
  
  # Create log directory
  mkdir -p "$LOG_DIR"
  rm -f "$PID_FILE"
  rm -f "$LOG_DIR"/*.log
  
  # Check Python availability
  local python_cmd="python3"
  if ! command -v python3 &>/dev/null; then
    if command -v python &>/dev/null; then
      python_cmd="python"
    else
      echo -e "${RED}✗ Python not found. Python services will not start.${NC}"
      echo -e "${DIM}  Install Python 3: brew install python3${NC}"
      python_cmd=""
    fi
  fi
  
  # ── Start Services ──
  echo -e "${BOLD}Starting services...${NC}"
  echo ""
  
  local started=0
  local gateway_entry=""
  
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port type path cmd <<< "$entry"
    
    # Save gateway for last
    if [[ "$name" == "API Gateway" ]]; then
      gateway_entry="$entry"
      continue
    fi
    
    local logfile="$LOG_DIR/$(log_name "$name").log"
    local service_dir="$ROOT/$path"
    
    if [[ ! -d "$service_dir" ]]; then
      printf "  ${RED}✗${NC} %-24s ${DIM}directory not found${NC}\n" "$name"
      continue
    fi
    
    if [[ "$type" == "python" ]]; then
      if [[ -z "$python_cmd" ]]; then
        printf "  ${YELLOW}⊘${NC} %-24s ${DIM}skipped (no Python)${NC}\n" "$name"
        continue
      fi

      # Check for venv
      local actual_python="$python_cmd"
      if [[ -f "$service_dir/venv/bin/python" ]]; then
        actual_python="$service_dir/venv/bin/python"
      elif [[ -f "$service_dir/.venv/bin/python" ]]; then
        actual_python="$service_dir/.venv/bin/python"
      fi
      
      # Replace "python" in the command with the resolved interpreter
      local actual_cmd="${cmd/python/$actual_python}"
      
      (cd "$service_dir" && $actual_cmd > "$logfile" 2>&1) &
      echo $! >> "$PID_FILE"
      printf "  ${MAGENTA}▸${NC} %-24s ${DIM}:${port} (Python)${NC}\n" "$name"
      
    elif [[ "$type" == "node" ]]; then
      (cd "$service_dir" && $cmd > "$logfile" 2>&1) &
      echo $! >> "$PID_FILE"
      printf "  ${BLUE}▸${NC} %-24s ${DIM}:${port} (Node)${NC}\n" "$name"
    fi
    
    started=$((started + 1))
  done
  
  # Wait for services to bind
  echo ""
  echo -e "${DIM}Waiting for services to start (5s)...${NC}"
  sleep 5
  
  # Start API Gateway last
  if [[ -n "$gateway_entry" ]]; then
    IFS='|' read -r name port type path cmd <<< "$gateway_entry"
    local logfile="$LOG_DIR/$(log_name "$name").log"
    (cd "$ROOT/$path" && $cmd > "$logfile" 2>&1) &
    echo $! >> "$PID_FILE"
    printf "  ${GREEN}▸${NC} %-24s ${DIM}:${port} (Gateway)${NC}\n" "$name"
    started=$((started + 1))
  fi
  
  # Wait for gateway
  echo ""
  echo -e "${DIM}Waiting for gateway to initialize (3s)...${NC}"
  sleep 3
  
  # ── Health Checks ──
  echo ""
  echo -e "${BOLD}Health Check${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"
  
  local up=0
  for entry in "${SERVICES[@]}"; do
    IFS='|' read -r name port type path cmd <<< "$entry"
    if health_check "$name" "$port"; then
      up=$((up + 1))
    fi
  done
  
  # ── Summary ──
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}${up}/${started} services running${NC}                                    ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Useful commands:${NC}"
  echo -e "    ${CYAN}./scripts/dev-start.sh status${NC}   — health check all services"
  echo -e "    ${CYAN}./scripts/dev-start.sh logs${NC}     — tail all log files"
  echo -e "    ${CYAN}./scripts/dev-start.sh stop${NC}     — stop everything"
  echo -e "    ${CYAN}tail -f .dev-logs/<service>.log${NC} — tail a specific service"
  echo ""
  echo -e "  ${BOLD}API Gateway:${NC} ${CYAN}http://127.0.0.1:3000/api${NC}"
  echo -e "  ${BOLD}Health:${NC}      ${CYAN}http://127.0.0.1:3000/health${NC}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "${1:-start}" in
  start)  do_start ;;
  stop)   do_stop  ;;
  status) do_status ;;
  logs)   do_logs  ;;
  *)
    echo "Usage: $0 {start|stop|status|logs}"
    exit 1
    ;;
esac
