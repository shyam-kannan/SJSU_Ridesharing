#!/usr/bin/env bash
# Lightweight deployment smoke test for API Gateway routing.
# Usage:
#   GATEWAY_URL=http://136.109.119.177 bash tests/test-gateway-smoke.sh
#   bash tests/test-gateway-smoke.sh http://localhost:3000

set -euo pipefail

BASE_URL="${1:-${GATEWAY_URL:-http://localhost:3000}}"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local body_file
  body_file="$(mktemp)"

  local status
  if [[ -n "$data" ]]; then
    status="$(curl -sS -m 20 -o "$body_file" -w "%{http_code}" -X "$method" \
      "$BASE_URL$path" \
      -H 'Content-Type: application/json' \
      --data-raw "$data")"
  else
    status="$(curl -sS -m 20 -o "$body_file" -w "%{http_code}" -X "$method" \
      "$BASE_URL$path")"
  fi

  printf '%s\n' "$status"
  cat "$body_file"
  rm -f "$body_file"
}

echo "Gateway smoke test target: $BASE_URL"

# 1) Gateway health
health_response="$(request GET /health)"
health_status="$(echo "$health_response" | head -n1)"
health_body="$(echo "$health_response" | tail -n +2)"

[[ "$health_status" == "200" ]] || fail "GET /health expected 200, got $health_status. Body: $health_body"
echo "$health_body" | grep -q '"API Gateway is running"' || fail "GET /health did not return gateway success message"
pass "Gateway health endpoint responds"

# 2) Auth route is proxied to auth-service (invalid creds should be 401, not 404/502)
login_response="$(request POST /api/auth/login '{"email":"bad@sjsu.edu","password":"bad"}')"
login_status="$(echo "$login_response" | head -n1)"
login_body="$(echo "$login_response" | tail -n +2)"

[[ "$login_status" == "401" ]] || fail "POST /api/auth/login expected 401, got $login_status. Body: $login_body"
echo "$login_body" | grep -qi 'invalid email or password' || fail "POST /api/auth/login body does not look like auth-service response"
pass "Auth proxy route is working"

# 3) Protected route should be blocked by gateway JWT middleware without token
booking_response="$(request POST /api/bookings '{"trip_id":"00000000-0000-0000-0000-000000000000","seats_booked":1}')"
booking_status="$(echo "$booking_response" | head -n1)"
booking_body="$(echo "$booking_response" | tail -n +2)"

[[ "$booking_status" == "401" ]] || fail "POST /api/bookings without token expected 401, got $booking_status. Body: $booking_body"
echo "$booking_body" | grep -qi 'access token required' || fail "POST /api/bookings did not return gateway JWT error"
pass "Gateway protected-route auth guard is working"

echo "All gateway smoke checks passed for $BASE_URL"
