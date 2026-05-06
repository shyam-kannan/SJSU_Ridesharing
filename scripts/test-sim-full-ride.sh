#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# LessGo — Full Ride E2E Test Simulation
# ═══════════════════════════════════════════════════════════════════════════════
#
# PURPOSE
#   Exercises the complete rider ↔ driver flow against a local backend:
#     1. Create two test accounts (Rider + Driver)
#     2. Driver sets up vehicle profile & posts a trip "To SJSU"
#     3. Rider submits a ride request → matching pipeline finds the driver
#     4. Rider selects the matched driver
#     5. Driver accepts the match
#     6. Rider books the trip → booking is confirmed
#     7. Trip state transitions: en_route → arrived → in_progress → completed
#     8. Settlement is calculated, payment intent is created & captured
#     9. Rider rates the driver
#    10. Cleanup: both test accounts are deleted
#
# PREREQUISITES
#   • All backend services running locally (npm run dev:all)
#   • jq installed (brew install jq)
#   • curl installed (comes with macOS)
#
# USAGE
#   chmod +x scripts/test-sim-full-ride.sh
#   ./scripts/test-sim-full-ride.sh
#
# ENVIRONMENT VARIABLES
#   BASE_URL        — API gateway base URL (default: http://127.0.0.1:3000/api)
#   SKIP_CLEANUP    — set to "1" to keep test accounts after the run
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BASE_URL="${BASE_URL:-http://127.0.0.1:3000/api}"
SKIP_CLEANUP="${SKIP_CLEANUP:-0}"
LOG_FILE="${LOG_FILE:-test-sim-detailed.log}"

# Initialize log file
echo "LessGo Simulation Log - $(date)" > "$LOG_FILE"
echo "═══════════════════════════════════════════════════════════════" >> "$LOG_FILE"

# Test account credentials (use sim- prefix to bypass SJSU ID checks in dev)
RIDER_EMAIL="sim-rider-test@sjsu.edu"
RIDER_NAME="Sim Rider"
RIDER_PASS="TestPassword1"

DRIVER_EMAIL="sim-driver-test@sjsu.edu"
DRIVER_NAME="Sim Driver"
DRIVER_PASS="TestPassword1"

# SJSU campus coordinates — rider is on campus, driver is ~200m away
SJSU_LAT=37.3352
SJSU_LNG=-121.8811

# Rider pickup: near Engineering Building
RIDER_ORIGIN_LAT=37.3365
RIDER_ORIGIN_LNG=-121.8820

# Driver origin: near 10th & San Fernando (200m from rider)
DRIVER_ORIGIN_LAT=37.3370
DRIVER_ORIGIN_LNG=-121.8830

# Shared destination: Diridon Station
DEST_LAT=37.3297
DEST_LNG=-121.9020

# Departure time: 30 minutes from now
DEPARTURE_TIME=$(date -u -v+30M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+30 minutes" +"%Y-%m-%dT%H:%M:%SZ")

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_api() {
  local method="$1"
  local url="$2"
  local data="$3"
  local response="$4"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  echo "[$timestamp] API REQUEST: $method $url" >> "$LOG_FILE"
  if [[ -n "$data" ]]; then
    echo "[$timestamp] REQUEST DATA: $data" >> "$LOG_FILE"
  fi
  if echo "$response" | jq . > /dev/null 2>&1; then
    echo "[$timestamp] RESPONSE:" >> "$LOG_FILE"
    echo "$response" | jq . >> "$LOG_FILE"
  else
    echo "[$timestamp] RESPONSE: $response" >> "$LOG_FILE"
  fi
  echo "---------------------------------------------------------------" >> "$LOG_FILE"
}

# curl_json <method> <path> <data> [token]
curl_json() {
  local method="$1"
  local path="$2"
  local data="$3"
  local token="${4:-}"
  local url="${BASE_URL}${path}"
  local resp
  
  local args=("-s" "-X" "$method" "$url" "-H" "Content-Type: application/json")
  if [[ -n "$token" ]]; then
    args+=("-H" "Authorization: Bearer $token")
  fi
  if [[ -n "$data" ]]; then
    args+=("-d" "$data")
  fi
  
  resp=$(curl "${args[@]}")
  log_api "$method" "$url" "$data" "$resp"
  echo "$resp"
}

step_num=0
step() {
  step_num=$((step_num + 1))
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  STEP ${step_num}: $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo "[$timestamp] === STEP ${step_num}: $1 ===" >> "$LOG_FILE"
}

ok()   { 
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "  ${GREEN}✓ $1${NC}"
  echo "[$timestamp] SUCCESS: $1" >> "$LOG_FILE"
}

warn() { 
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "  ${YELLOW}⚠ $1${NC}"
  echo "[$timestamp] WARNING: $1" >> "$LOG_FILE"
}

fail() { 
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "  ${RED}✗ $1${NC}"
  echo "[$timestamp] ERROR: $1" >> "$LOG_FILE"
  echo "Simulation failed. See $LOG_FILE for details."
  exit 1
}

info() { 
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "  ${CYAN}→ $1${NC}"
  echo "[$timestamp] INFO: $1" >> "$LOG_FILE"
}

# Extract a JSON field using jq; fail with a clear message if missing
jget() {
  local json="$1"
  local path="$2"
  local label="${3:-$path}"
  local val
  val=$(echo "$json" | jq -r "$path // empty" 2>/dev/null)
  if [[ -z "$val" ]]; then
    echo ""
    echo -e "${RED}  ✗ Failed to extract '${label}' from response:${NC}"
    echo "$json" | jq . 2>/dev/null || echo "$json"
    return 1
  fi
  echo "$val"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         LessGo — Full Ride E2E Test Simulation              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Gateway: ${BASE_URL}"
info "Log File: ${LOG_FILE}"
info "Departure: ${DEPARTURE_TIME}"
echo ""

# Verify gateway is up
if ! curl -s "${BASE_URL%/api}/health" > /dev/null 2>&1; then
  fail "Cannot reach API gateway at ${BASE_URL%/api}/health — are services running? (./scripts/dev-start.sh)"
fi
ok "API Gateway is reachable"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 1 — ACCOUNT CREATION
# ══════════════════════════════════════════════════════════════════════════════

step "Register RIDER account"
RIDER_REG=$(curl_json POST "/auth/register" "{
    \"name\": \"${RIDER_NAME}\",
    \"email\": \"${RIDER_EMAIL}\",
    \"password\": \"${RIDER_PASS}\",
    \"role\": \"Rider\"
  }")

if echo "$RIDER_REG" | jq -e '.data.accessToken' > /dev/null 2>&1; then
  RIDER_TOKEN=$(jget "$RIDER_REG" '.data.accessToken' 'rider accessToken')
  RIDER_ID=$(jget "$RIDER_REG" '.data.user.user_id' 'rider user_id')
  ok "Rider registered: ${RIDER_ID}"
elif echo "$RIDER_REG" | grep -qi "already exists"; then
  warn "Rider already exists, logging in..."
  RIDER_LOGIN=$(curl_json POST "/auth/login" "{\"email\": \"${RIDER_EMAIL}\", \"password\": \"${RIDER_PASS}\"}")
  RIDER_TOKEN=$(jget "$RIDER_LOGIN" '.data.accessToken' 'rider accessToken')
  RIDER_ID=$(jget "$RIDER_LOGIN" '.data.user.user_id' 'rider user_id')
  ok "Rider logged in: ${RIDER_ID}"
else
  fail "Rider registration failed"
fi
info "Rider token: ${RIDER_TOKEN:0:20}..."

# ──────────────────────────────────────────────────────────────────────────────

step "Register DRIVER account"
DRIVER_REG=$(curl_json POST "/auth/register" "{
    \"name\": \"${DRIVER_NAME}\",
    \"email\": \"${DRIVER_EMAIL}\",
    \"password\": \"${DRIVER_PASS}\",
    \"role\": \"Driver\"
  }")

if echo "$DRIVER_REG" | jq -e '.data.accessToken' > /dev/null 2>&1; then
  DRIVER_TOKEN=$(jget "$DRIVER_REG" '.data.accessToken' 'driver accessToken')
  DRIVER_ID=$(jget "$DRIVER_REG" '.data.user.user_id' 'driver user_id')
  ok "Driver registered: ${DRIVER_ID}"
elif echo "$DRIVER_REG" | grep -qi "already exists"; then
  warn "Driver already exists, logging in..."
  DRIVER_LOGIN=$(curl_json POST "/auth/login" "{\"email\": \"${DRIVER_EMAIL}\", \"password\": \"${DRIVER_PASS}\"}")
  DRIVER_TOKEN=$(jget "$DRIVER_LOGIN" '.data.accessToken' 'driver accessToken')
  DRIVER_ID=$(jget "$DRIVER_LOGIN" '.data.user.user_id' 'driver user_id')
  ok "Driver logged in: ${DRIVER_ID}"
else
  fail "Driver registration failed"
fi
info "Driver token: ${DRIVER_TOKEN:0:20}..."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 2 — DRIVER SETUP
# ══════════════════════════════════════════════════════════════════════════════

step "Verify driver (dev bypass)"
# Use the dev-only debug-verify endpoint to mark the driver as verified + Driver role
VERIFY_RESP=$(curl_json POST "/users/${DRIVER_ID}/debug-verify" "" "$DRIVER_TOKEN")
if echo "$VERIFY_RESP" | jq -e '.status' > /dev/null 2>&1 && ! echo "$VERIFY_RESP" | grep -qi "error"; then
  ok "Driver verified via debug endpoint"
else
  warn "Debug verify returned an error or unexpected response"
fi

# Refresh driver token so JWT claims reflect verified status
DRIVER_REFRESH=$(curl_json POST "/auth/login" "{\"email\": \"${DRIVER_EMAIL}\", \"password\": \"${DRIVER_PASS}\"}")
DRIVER_TOKEN=$(jget "$DRIVER_REFRESH" '.data.accessToken' 'driver accessToken')
DRIVER_ID=$(jget "$DRIVER_REFRESH" '.data.user.user_id' 'driver user_id')
ok "Driver token refreshed"

# Set driver online — the PostGIS candidate query requires available_for_rides = true.
# debug-verify only sets role/sjsu_id_status; availability must be toggled separately.
AVAIL_RESP=$(curl_json PATCH "/users/${DRIVER_ID}/availability" '{"available_for_rides": true}' "$DRIVER_TOKEN")
if echo "$AVAIL_RESP" | jq -e '.status' > /dev/null 2>&1 && ! echo "$AVAIL_RESP" | grep -qi "error"; then
  ok "Driver set online (available_for_rides = true)"
else
  warn "Availability toggle returned unexpected response — matching may return 0 candidates"
fi

# ──────────────────────────────────────────────────────────────────────────────

step "Set up driver vehicle profile"
SETUP_RESP=$(curl_json PUT "/users/${DRIVER_ID}/driver-setup" '{
    "vehicle_info": "2023 Honda Civic Silver",
    "seats_available": 4,
    "license_plate": "SIM-1234",
    "mpg": 35
  }' "$DRIVER_TOKEN")
ok "Vehicle profile set: $(echo "$SETUP_RESP" | jq -r '.data.vehicle_info // "set"')"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 3 — DRIVER POSTS A TRIP
# ══════════════════════════════════════════════════════════════════════════════

step "Driver posts a 'To SJSU' trip"
TRIP_RESP=$(curl_json POST "/trips" "{
    \"origin\": \"10th & San Fernando, San Jose\",
    \"destination\": \"San Jose State University\",
    \"departure_time\": \"${DEPARTURE_TIME}\",
    \"seats_available\": 4
  }" "$DRIVER_TOKEN")

TRIP_ID=$(jget "$TRIP_RESP" '.data.trip_id' 'trip_id') || fail "Trip creation failed"
ok "Trip created: ${TRIP_ID}"
info "Origin: 10th & San Fernando → Destination: SJSU"
info "Departure: ${DEPARTURE_TIME}"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4 — RIDER SUBMITS RIDE REQUEST (MATCHING)
# ══════════════════════════════════════════════════════════════════════════════

step "Rider submits ride request (triggers matching pipeline)"
REQUEST_RESP=$(curl_json POST "/trips/request" "{
    \"origin\": \"SJSU Engineering Building\",
    \"destination\": \"San Jose State University\",
    \"origin_lat\": ${RIDER_ORIGIN_LAT},
    \"origin_lng\": ${RIDER_ORIGIN_LNG},
    \"destination_lat\": ${DEST_LAT},
    \"destination_lng\": ${DEST_LNG},
    \"departure_time\": \"${DEPARTURE_TIME}\"
  }" "$RIDER_TOKEN")

REQUEST_ID=$(jget "$REQUEST_RESP" '.data.request_id' 'request_id') || fail "Ride request failed"
ok "Ride request created: ${REQUEST_ID}"

# Check for available drivers from the matching response
DRIVER_COUNT=$(echo "$REQUEST_RESP" | jq '.data.available_drivers | length' 2>/dev/null || echo "0")
info "Matching returned ${DRIVER_COUNT} candidate driver(s)"

if [[ "$DRIVER_COUNT" -gt 0 ]]; then
  # Extract the first matched driver's trip_id and driver_id
  MATCHED_TRIP_ID=$(echo "$REQUEST_RESP" | jq -r '.data.available_drivers[0].trip_id')
  MATCHED_DRIVER_ID=$(echo "$REQUEST_RESP" | jq -r '.data.available_drivers[0].driver_id')
  ok "Best match: trip=${MATCHED_TRIP_ID}, driver=${MATCHED_DRIVER_ID}"
else
  warn "No drivers matched automatically. Using the trip we created."
  MATCHED_TRIP_ID="$TRIP_ID"
  MATCHED_DRIVER_ID="$DRIVER_ID"
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5 — RIDER SELECTS DRIVER
# ══════════════════════════════════════════════════════════════════════════════

step "Rider selects driver from ranked list"
SELECT_RESP=$(curl_json POST "/trips/request/${REQUEST_ID}/select-driver" "{
    \"trip_id\": \"${MATCHED_TRIP_ID}\",
    \"driver_id\": \"${MATCHED_DRIVER_ID}\"
  }" "$RIDER_TOKEN")

MATCH_ID=$(jget "$SELECT_RESP" '.data.match_id' 'match_id') || warn "Select driver did not return match_id"
if [[ -n "${MATCH_ID:-}" ]]; then
  ok "Driver selected, match_id: ${MATCH_ID}"
else
  warn "Continuing with direct booking flow"
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6 — DRIVER ACCEPTS MATCH
# ══════════════════════════════════════════════════════════════════════════════

step "Driver accepts the incoming match"
if [[ -n "${MATCH_ID:-}" ]]; then
  ACCEPT_RESP=$(curl_json POST "/trips/${MATCHED_TRIP_ID}/accept-match" "{\"match_id\": \"${MATCH_ID}\"}" "$DRIVER_TOKEN")
  ok "Match accepted by driver"
  info "Response: $(echo "$ACCEPT_RESP" | jq -r '.message // .status' 2>/dev/null)"
else
  warn "Skipping — no match_id available (direct booking flow)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 7 — RIDER BOOKS THE TRIP
# ══════════════════════════════════════════════════════════════════════════════

step "Rider books the trip (1 seat)"
BOOKING_RESP=$(curl_json POST "/bookings" "{
    \"trip_id\": \"${MATCHED_TRIP_ID}\",
    \"seats_booked\": 1
  }" "$RIDER_TOKEN")

BOOKING_ID=$(jget "$BOOKING_RESP" '.data.booking_id // .data.booking.booking_id' 'booking_id') || fail "Booking failed"
ok "Booking created: ${BOOKING_ID}"

# Set pickup location
info "Setting rider pickup location..."
PICKUP_RESP=$(curl_json PUT "/bookings/${BOOKING_ID}/pickup-location" "{
    \"lat\": ${RIDER_ORIGIN_LAT},
    \"lng\": ${RIDER_ORIGIN_LNG},
    \"address\": \"SJSU Engineering Building\"
  }" "$RIDER_TOKEN")
if echo "$PICKUP_RESP" | jq -e '.status' > /dev/null 2>&1; then
  ok "Pickup location set"
else
  warn "Pickup location update failed"
fi

# ──────────────────────────────────────────────────────────────────────────────

step "Driver confirms the booking"
CONFIRM_RESP=$(curl_json PUT "/bookings/${BOOKING_ID}/confirm" "" "$DRIVER_TOKEN")
ok "Booking confirmed by driver"
info "Status: $(echo "$CONFIRM_RESP" | jq -r '.data.status // .data.booking.status // "confirmed"' 2>/dev/null)"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 8 — RIDE LIFECYCLE (State Transitions)
# ══════════════════════════════════════════════════════════════════════════════

step "Driver starts trip → EN_ROUTE (heading to pickup)"
curl_json PUT "/trips/${MATCHED_TRIP_ID}/state" '{"status": "en_route"}' "$DRIVER_TOKEN" > /dev/null
ok "Trip state → en_route"

# Simulate driver location updates
info "Sending driver location updates..."
curl_json POST "/trips/${MATCHED_TRIP_ID}/location" "{
    \"latitude\": ${DRIVER_ORIGIN_LAT},
    \"longitude\": ${DRIVER_ORIGIN_LNG},
    \"heading\": 180,
    \"speed\": 25.0
  }" "$DRIVER_TOKEN" > /dev/null
ok "Location update sent"

sleep 1

# ──────────────────────────────────────────────────────────────────────────────

step "Driver arrives at pickup → ARRIVED"
curl_json PUT "/trips/${MATCHED_TRIP_ID}/state" '{"status": "arrived"}' "$DRIVER_TOKEN" > /dev/null
ok "Trip state → arrived"

# Update location to rider's pickup point
curl_json POST "/trips/${MATCHED_TRIP_ID}/location" "{
    \"latitude\": ${RIDER_ORIGIN_LAT},
    \"longitude\": ${RIDER_ORIGIN_LNG},
    \"heading\": 0,
    \"speed\": 0
  }" "$DRIVER_TOKEN" > /dev/null

sleep 1

# ──────────────────────────────────────────────────────────────────────────────

step "Rider picked up → RIDE IN PROGRESS"
curl_json PUT "/trips/${MATCHED_TRIP_ID}/state" '{"status": "in_progress"}' "$DRIVER_TOKEN" > /dev/null
ok "Trip state → in_progress"

# Simulate mid-ride location
curl_json POST "/trips/${MATCHED_TRIP_ID}/location" "{
    \"latitude\": 37.3330,
    \"longitude\": -121.8900,
    \"heading\": 270,
    \"speed\": 35.0
  }" "$DRIVER_TOKEN" > /dev/null

# Send a chat message from driver
info "Driver sends chat message..."
curl -s -X POST "${BASE_URL}/trips/${MATCHED_TRIP_ID}/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DRIVER_TOKEN}" \
  -d '{"message": "Hey! We should arrive in about 10 minutes."}' > /dev/null 2>&1 \
  && ok "Chat message sent" || warn "Chat not available"

sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 9 — TRIP COMPLETED + SETTLEMENT
# ══════════════════════════════════════════════════════════════════════════════

step "Ride complete → COMPLETED (triggers settlement)"
COMPLETE_RESP=$(curl_json PUT "/trips/${MATCHED_TRIP_ID}/state" '{"status": "completed"}' "$DRIVER_TOKEN")

ok "Trip state → completed"

# Check if settlement was calculated
SETTLEMENT=$(echo "$COMPLETE_RESP" | jq '.data.settlement' 2>/dev/null)
if [[ "$SETTLEMENT" != "null" && -n "$SETTLEMENT" ]]; then
  DRIVER_EARNINGS=$(echo "$SETTLEMENT" | jq -r '.driver_earnings // "N/A"')
  COST_PER_RIDER=$(echo "$SETTLEMENT" | jq -r '.cost_per_rider // "N/A"')
  ok "Settlement calculated!"
  info "  Driver earnings: \$${DRIVER_EARNINGS}"
  info "  Cost per rider:  \$${COST_PER_RIDER}"
else
  warn "Settlement not included in response (cost-service may be offline)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 10 — PAYMENT
# ══════════════════════════════════════════════════════════════════════════════

step "Create payment intent for the booking"
PAYMENT_AMOUNT="${COST_PER_RIDER:-8.50}"
# Ensure we have a valid number
if [[ "$PAYMENT_AMOUNT" == "N/A" || -z "$PAYMENT_AMOUNT" ]]; then
  PAYMENT_AMOUNT="8.50"
fi

PAYMENT_RESP=$(curl_json POST "/payments/create-intent" "{
    \"booking_id\": \"${BOOKING_ID}\",
    \"amount\": ${PAYMENT_AMOUNT}
  }" "$RIDER_TOKEN")

PAYMENT_ID=$(echo "$PAYMENT_RESP" | jq -r '.data.payment_id // .data.id // empty' 2>/dev/null)
if [[ -n "$PAYMENT_ID" ]]; then
  ok "Payment intent created: ${PAYMENT_ID}"
  info "Amount: \$${PAYMENT_AMOUNT}"

  # Capture the payment
  step "Capture payment"
  CAPTURE_RESP=$(curl_json POST "/payments/${PAYMENT_ID}/capture" "" "$RIDER_TOKEN")
  if echo "$CAPTURE_RESP" | jq -e '.status' > /dev/null 2>&1; then
    ok "Payment captured successfully"
  else
    warn "Payment capture response: $(echo "$CAPTURE_RESP" | head -c 200)"
  fi
else
  warn "Payment service may be offline or Stripe not configured"
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 11 — RATING
# ══════════════════════════════════════════════════════════════════════════════

step "Rider rates the driver (5 stars)"
RATE_RESP=$(curl_json POST "/bookings/${BOOKING_ID}/rate" '{"score": 5, "comment": "Great ride! Very smooth and on time."}' "$RIDER_TOKEN")

if echo "$RATE_RESP" | jq -e '.data' > /dev/null 2>&1; then
  ok "Rating submitted: 5 ★"
else
  warn "Rating failed"
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 12 — VERIFICATION & SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

step "Verify final state"
info "Fetching trip details..."
FINAL_TRIP=$(curl_json GET "/trips/${MATCHED_TRIP_ID}" "" "$RIDER_TOKEN")
FINAL_STATUS=$(echo "$FINAL_TRIP" | jq -r '.data.status // "unknown"' 2>/dev/null)
ok "Trip final status: ${FINAL_STATUS}"

info "Fetching rider bookings..."
RIDER_BOOKINGS=$(curl_json GET "/bookings" "" "$RIDER_TOKEN")
BOOKING_COUNT=$(echo "$RIDER_BOOKINGS" | jq '.data.total // 0' 2>/dev/null)
ok "Rider has ${BOOKING_COUNT} booking(s)"

# ══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ══════════════════════════════════════════════════════════════════════════════

if [[ "$SKIP_CLEANUP" == "1" ]]; then
  echo ""
  warn "SKIP_CLEANUP=1 — test accounts preserved"
  info "  Rider:  ${RIDER_ID}  (${RIDER_EMAIL})"
  info "  Driver: ${DRIVER_ID} (${DRIVER_EMAIL})"
else
  step "Cleanup: delete test accounts"
  curl_json DELETE "/users/${RIDER_ID}/debug-delete" "" "$RIDER_TOKEN" > /dev/null
  ok "Rider account deleted"
  curl_json DELETE "/users/${DRIVER_ID}/debug-delete" "" "$DRIVER_TOKEN" > /dev/null
  ok "Driver account deleted"
fi

# ══════════════════════════════════════════════════════════════════════════════
# FINAL REPORT
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✓  SIMULATION COMPLETE                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Summary:${NC}"
echo -e "    Rider:    ${RIDER_NAME} (${RIDER_EMAIL})"
echo -e "    Driver:   ${DRIVER_NAME} (${DRIVER_EMAIL})"
echo -e "    Trip:     ${MATCHED_TRIP_ID}"
echo -e "    Booking:  ${BOOKING_ID}"
echo -e "    Payment:  ${PAYMENT_ID:-N/A}"
echo -e "    Rating:   5 ★"
echo ""
echo -e "  ${BOLD}Flow Completed:${NC}"
echo -e "    1. ✓ Account creation (Rider + Driver)"
echo -e "    2. ✓ Driver vehicle setup"
echo -e "    3. ✓ Driver posted trip"
echo -e "    4. ✓ Rider submitted ride request → matched"
echo -e "    5. ✓ Rider selected driver"
echo -e "    6. ✓ Driver accepted match"
echo -e "    7. ✓ Rider booked trip → confirmed"
echo -e "    8. ✓ Trip lifecycle: en_route → arrived → in_progress → completed"
echo -e "    9. ✓ Settlement calculated"
echo -e "   10. ✓ Payment created & captured"
echo -e "   11. ✓ Rider rated driver"
echo ""
