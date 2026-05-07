#!/bin/bash

# LessGo Backend Services Launcher for macOS
# This script opens each service in a new Terminal tab

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Node.js services: "Name:path"
declare -a node_services=(
  "API Gateway:services/api-gateway"
  "Auth Service:services/auth-service"
  "User Service:services/user-service"
  "Trip Service:services/trip-service"
  "Booking Service:services/booking-service"
  "Payment Service:services/payment-service"
  "Notification Service:services/notification-service"
  "Cost Calculation:services/cost-calculation-service"
  "Safety Service:services/safety-service"
)

# Python services: "Name:path:port:module"
declare -a python_services=(
  "Embedding Service:services/embedding-service:3010:app.main:app"
  "Routing Service:services/routing-service:8002:app.main:app"
)

_tab_counter=0
launch_tab() {
  local name="$1"
  local cmd="$2"
  _tab_counter=$((_tab_counter + 1))
  local tmpfile="/tmp/lessgo_service_${_tab_counter}.sh"
  printf '#!/bin/bash\n%s\n' "$cmd" > "$tmpfile"
  chmod +x "$tmpfile"
  osascript -e "tell application \"Terminal\" to activate" \
            -e "tell application \"System Events\" to keystroke \"t\" using command down" \
            -e "delay 0.5" \
            -e "tell application \"Terminal\" to do script \"$tmpfile\" in front window"
  echo "✅ Launched $name"
  sleep 0.5
}

echo "Starting all backend services..."

for service in "${node_services[@]}"; do
  IFS=':' read -r name path <<< "$service"
  launch_tab "$name" "cd \"$PROJECT_ROOT/$path\" && echo \"Starting $name...\" && npm run dev"
done

for service in "${python_services[@]}"; do
  IFS=':' read -r name path port module <<< "$service"
  launch_tab "$name" "cd \"$PROJECT_ROOT/$path\" && echo \"Starting $name...\" && python3 -m venv .venv && source .venv/bin/activate && pip install -q -r requirements.txt && uvicorn $module --host 0.0.0.0 --port $port --reload"
done

echo "All services launched! Check your Terminal tabs."
