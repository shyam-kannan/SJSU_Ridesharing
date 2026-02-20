#!/bin/bash

# LessGo Backend Services Launcher for macOS
# This script opens each service in a new Terminal tab

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Array of services
declare -a services=(
  "API Gateway:services/api-gateway"
  "Auth Service:services/auth-service"
  "User Service:services/user-service"
  "Trip Service:services/trip-service"
  "Booking Service:services/booking-service"
  "Payment Service:services/payment-service"
  "Notification Service:services/notification-service"
  "Cost Calculation:services/cost-calculation-service"
)

echo "🚀 Starting all backend services..."

# Open each service in a new Terminal tab
for service in "${services[@]}"; do
  IFS=':' read -r name path <<< "$service"
  
  osascript <<EOF
    tell application "Terminal"
      activate
      tell application "System Events" to keystroke "t" using command down
      delay 0.5
      do script "cd \"$PROJECT_ROOT/$path\" && echo \"Starting $name...\" && npm run dev" in front window
    end tell
EOF
  
  echo "✅ Launched $name"
  sleep 0.5
done

echo "✨ All services launched! Check your Terminal tabs."
