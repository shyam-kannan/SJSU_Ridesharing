#!/bin/bash
echo "Stopping all services..."
pkill -f "ts-node-dev" 2>/dev/null
pkill -f "dotenv.*ts-node-dev" 2>/dev/null
pkill -f "python.*main.py" 2>/dev/null
pkill -f "uvicorn" 2>/dev/null
sleep 2

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Node services..."
cd "$ROOT/services/auth-service" && npm run dev > /tmp/auth.log 2>&1 &
cd "$ROOT/services/user-service" && npm run dev > /tmp/user.log 2>&1 &
cd "$ROOT/services/trip-service" && npm run dev > /tmp/trip.log 2>&1 &
cd "$ROOT/services/booking-service" && npm run dev > /tmp/booking.log 2>&1 &
cd "$ROOT/services/notification-service" && npm run dev > /tmp/notification.log 2>&1 &
cd "$ROOT/services/cost-calculation-service" && npm run dev > /tmp/cost.log 2>&1 &
cd "$ROOT/services/payment-service" && npm run dev > /tmp/payment.log 2>&1 &
cd "$ROOT/services/safety-service" && npm run dev > /tmp/safety.log 2>&1 &

echo "Starting Python services..."
cd "$ROOT/services/routing-service" && python app/main.py > /tmp/routing.log 2>&1 &
cd "$ROOT/services/embedding-service" && python app/main.py > /tmp/embedding.log 2>&1 &
cd "$ROOT/services/grouping-service" && python app/main.py > /tmp/grouping.log 2>&1 &

sleep 4

echo "Starting API gateway..."
cd "$ROOT/services/api-gateway" && npm run dev > /tmp/gateway.log 2>&1 &

sleep 4

echo ""
echo "Health check..."
check() {
  local name=$1
  local url=$2
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null)
  if [ "$status" = "200" ]; then
    echo "  ✓ $name ($url)"
  else
    echo "  ✗ $name ($url) — HTTP $status"
  fi
}

check "api-gateway      :3000" "http://127.0.0.1:3000/health"
check "auth-service     :3001" "http://127.0.0.1:3001/health"
check "user-service     :3002" "http://127.0.0.1:3002/health"
check "trip-service     :3003" "http://127.0.0.1:3003/health"
check "booking-service  :3004" "http://127.0.0.1:3004/health"
check "payment-service  :3005" "http://127.0.0.1:3005/health"
check "notification     :3006" "http://127.0.0.1:3006/health"
check "cost-service     :3009" "http://127.0.0.1:3009/health"
check "embedding-service:3010" "http://127.0.0.1:3010/health"
check "grouping-service :8001" "http://127.0.0.1:8001/health"
check "routing-service  :8002" "http://127.0.0.1:8002/health"
check "safety-service   :8005" "http://127.0.0.1:8005/health"
