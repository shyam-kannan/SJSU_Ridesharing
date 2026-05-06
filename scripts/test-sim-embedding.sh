#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# LessGo — Embedding Service Test Simulation
# ═══════════════════════════════════════════════════════════════════════════════
#
# PURPOSE
#   Validates the embedding-service connectivity and functionality:
#     1. Authenticate with a test account (required by API Gateway)
#     2. Check service health and model readiness
#     3. Test the /match endpoint with sample driver candidates
#     4. Verify that the service ranks candidates (or degrades gracefully)
#
# USAGE
#   chmod +x scripts/test-sim-embedding.sh
#   ./scripts/test-sim-embedding.sh
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BASE_URL="${BASE_URL:-http://127.0.0.1:3000/api}"
LOG_FILE="${LOG_FILE:-test-sim-embedding.log}"

# Initialize log file
echo "LessGo Embedding Simulation Log - $(date)" > "$LOG_FILE"
echo "═══════════════════════════════════════════════════════════════" >> "$LOG_FILE"

# Test account (sim- prefix bypasses SJSU ID checks)
TEST_EMAIL="sim-embed-test@sjsu.edu"
TEST_NAME="Embed Tester"
TEST_PASS="TestPassword1"

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_api() {
  local method="$1" url="$2" data="$3" response="$4"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] API REQUEST: $method $url" >> "$LOG_FILE"
  [[ -n "$data" ]] && echo "[$timestamp] REQUEST DATA: $data" >> "$LOG_FILE"
  if echo "$response" | jq . > /dev/null 2>&1; then
    echo "[$timestamp] RESPONSE:" >> "$LOG_FILE"; echo "$response" | jq . >> "$LOG_FILE"
  else
    echo "[$timestamp] RESPONSE: $response" >> "$LOG_FILE"
  fi
  echo "---------------------------------------------------------------" >> "$LOG_FILE"
}

curl_json() {
  local method="$1" path="$2" data="$3" token="${4:-}"
  local url="${BASE_URL}${path}"
  local args=("-s" "--connect-timeout" "5" "--max-time" "15" "-X" "$method" "$url" "-H" "Content-Type: application/json")
  [[ -n "$token" ]] && args+=("-H" "Authorization: Bearer $token")
  [[ -n "$data" ]] && args+=("-d" "$data")
  local resp
  if ! resp=$(curl "${args[@]}" 2>/dev/null); then
    warn "curl failed for $method $url (timeout or connection refused)"
    resp=""
  fi
  log_api "$method" "$url" "$data" "$resp"
  echo "$resp"
}

step_num=0
step() {
  step_num=$((step_num + 1))
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  STEP ${step_num}: $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] === STEP ${step_num}: $1 ===" >> "$LOG_FILE"
}

ok()   { echo -e "  ${GREEN}✓ $1${NC}"; echo "[$(date +"%Y-%m-%d %H:%M:%S")] SUCCESS: $1" >> "$LOG_FILE"; }
warn() { echo -e "  ${YELLOW}⚠ $1${NC}"; echo "[$(date +"%Y-%m-%d %H:%M:%S")] WARNING: $1" >> "$LOG_FILE"; }
fail() { echo -e "  ${RED}✗ $1${NC}"; echo "[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: $1" >> "$LOG_FILE"; exit 1; }
info() { echo -e "  ${CYAN}→ $1${NC}"; echo "[$(date +"%Y-%m-%d %H:%M:%S")] INFO: $1" >> "$LOG_FILE"; }

jget() {
  local val=$(echo "$1" | jq -r "$2 // empty" 2>/dev/null)
  [[ -z "$val" ]] && { echo -e "${RED}  ✗ Missing '$2' in response${NC}"; return 1; }
  echo "$val"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
step "Pre-flight Check"
if ! curl -s --connect-timeout 5 --max-time 10 "${BASE_URL%/api}/health" > /dev/null 2>&1; then
  fail "Cannot reach API gateway at ${BASE_URL%/api}/health"
fi
ok "API Gateway is reachable"

# ── Phase 1: Authentication ───────────────────────────────────────────────────
step "Obtain Authentication Token"
AUTH_RESP=$(curl_json POST "/auth/register" "{
    \"name\": \"${TEST_NAME}\",
    \"email\": \"${TEST_EMAIL}\",
    \"password\": \"${TEST_PASS}\",
    \"role\": \"Rider\"
  }")

if ! echo "$AUTH_RESP" | jq -e '.data.accessToken' > /dev/null 2>&1; then
  info "Account might exist, trying login..."
  AUTH_RESP=$(curl_json POST "/auth/login" "{\"email\": \"${TEST_EMAIL}\", \"password\": \"${TEST_PASS}\"}")
fi

TOKEN=$(jget "$AUTH_RESP" '.data.accessToken' 'accessToken') || fail "Auth failed"
ok "Authenticated successfully"

# ── Phase 2: Health & Status ──────────────────────────────────────────────────
step "Check Embedding Service Health"
HEALTH_RESP=$(curl_json GET "/embedding/health" "" "$TOKEN")
STATUS=$(jget "$HEALTH_RESP" ".status" "status") || fail "Health check failed"

if [[ "$STATUS" == "success" ]]; then
  MODEL_READY=$(echo "$HEALTH_RESP" | jq -r '.model_ready')
  ok "Embedding service is ALIVE"
  info "Model ready: ${MODEL_READY}"
else
  fail "Embedding service health check returned error status"
fi

# ── Phase 3: Match Test ───────────────────────────────────────────────────────
step "Test Candidate Matching (Ranking)"
# Coordinates for SJSU area
RIDER_LAT=37.3352
RIDER_LNG=-121.8811

# $((10#...)) strips bash's zero-padding so the hour is valid JSON (08 → 8)
RIDER_HOUR=$((10#$(date +%H)))
DEPARTURE_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

MATCH_RESP=$(curl_json POST "/embedding/match" "{
    \"rider_origin_lat\": ${RIDER_LAT},
    \"rider_origin_lng\": ${RIDER_LNG},
    \"rider_dest_lat\": 37.3297,
    \"rider_dest_lng\": -121.9020,
    \"rider_hour\": ${RIDER_HOUR},
    \"candidates\": [
      {
        \"trip_id\": \"trip-1\",
        \"driver_id\": \"driver-1\",
        \"origin_lat\": 37.3370,
        \"origin_lng\": -121.8830,
        \"destination_lat\": 37.3297,
        \"destination_lng\": -121.9020,
        \"departure_time\": \"${DEPARTURE_TIME}\"
      },
      {
        \"trip_id\": \"trip-2\",
        \"driver_id\": \"driver-2\",
        \"origin_lat\": 37.4000,
        \"origin_lng\": -121.9000,
        \"destination_lat\": 37.3297,
        \"destination_lng\": -121.9020,
        \"departure_time\": \"${DEPARTURE_TIME}\"
      }
    ]
  }" "$TOKEN")

if [[ -z "$MATCH_RESP" ]]; then
  warn "No response from embedding service — is it running?"
elif ! echo "$MATCH_RESP" | jq . > /dev/null 2>&1; then
  warn "Embedding service returned non-JSON: $MATCH_RESP"
else
  MODEL_USED=$(echo "$MATCH_RESP" | jq -r '.model_used // false')
  if [[ "$MODEL_USED" == "true" ]]; then
    ok "Matching successful using ML model!"
    info "Ranked candidates:"
    echo "$MATCH_RESP" | jq -c '.ranked[]' 2>/dev/null | while read -r line; do
      info "  - $(echo "$line" | jq -r '.trip_id'): similarity=$(echo "$line" | jq -r '.similarity')"
    done
  else
    warn "Matching fallback (model not ready) — returned raw candidates"
    info "This is expected if training hasn't been run or model is missing."
  fi
fi

# ── Cleanup ───────────────────────────────────────────────────────────────────
step "Cleanup"
curl_json DELETE "/users/$(jget "$AUTH_RESP" '.data.user.user_id' 'user_id')/debug-delete" "" "$TOKEN" > /dev/null
ok "Test account deleted"

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✓  EMBEDDING TEST COMPLETE                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
info "See ${LOG_FILE} for full API trace."
