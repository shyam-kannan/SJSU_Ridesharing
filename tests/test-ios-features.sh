#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# LessGo — iOS Features Test Suite
# Tests: Email notifications, Change Password, Device Token,
#        Notification Preferences, Report Issue
# Usage: ./tests/test-ios-features.sh
# ═══════════════════════════════════════════════════════════════

BASE="http://127.0.0.1"
AUTH="$BASE:3001"
USER="$BASE:3002"
NOTIF="$BASE:3006"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

pass=0; fail=0

check() {
  local label="$1"; local status="$2"; local body="$3"
  if echo "$body" | grep -q '"status":"success"' 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} $label"
    ((pass++))
  else
    echo -e "  ${RED}❌${NC} $label"
    echo -e "     ${YELLOW}Status: $status | Body: ${body:0:200}${NC}"
    ((fail++))
  fi
}

# ── Pre-flight ──────────────────────────────────────────────────
echo -e "\n${BOLD}iOS Features Test Suite${NC}\n"
echo "Checking services..."

for port in 3001 3002 3006; do
  if curl -s "http://127.0.0.1:$port/health" | grep -q '"status":"success"'; then
    echo -e "  ${GREEN}✅${NC} Port $port is up"
  else
    echo -e "  ${RED}❌${NC} Port $port is DOWN — start the service first"
  fi
done

# ── Register a test user ────────────────────────────────────────
echo -e "\n${BOLD}Part 0: Setup Test User${NC}"

TS=$(date +%s)
TEST_EMAIL="testfeatures_${TS}@sjsu.edu"
TEST_PASS="TestPass123!"

REGISTER=$(curl -s -X POST "$AUTH/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Feature Tester\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASS\",\"role\":\"Rider\"}")
check "Register test user" "201" "$REGISTER"

TOKEN=$(echo "$REGISTER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('accessToken',''))" 2>/dev/null)
USER_ID=$(echo "$REGISTER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('user',{}).get('user_id',''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo -e "  ${RED}❌${NC} Could not extract token — stopping test"
  exit 1
fi
echo "  Token: ${TOKEN:0:30}..."
echo "  User ID: $USER_ID"

# ── Part 1: Change Password ─────────────────────────────────────
echo -e "\n${BOLD}Part 1: Change Password${NC}"

CHANGE=$(curl -s -X PUT "$AUTH/auth/change-password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"currentPassword\":\"$TEST_PASS\",\"newPassword\":\"NewPass456!\"}")
check "Change password (correct current)" "200" "$CHANGE"

WRONG=$(curl -s -X PUT "$AUTH/auth/change-password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"currentPassword\":\"WrongPass999\",\"newPassword\":\"AnotherPass1!\"}")
if echo "$WRONG" | grep -q '"status":"error"'; then
  echo -e "  ${GREEN}✅${NC} Change password rejects wrong current password"
  ((pass++))
else
  echo -e "  ${RED}❌${NC} Should reject wrong current password"
  ((fail++))
fi

SHORT=$(curl -s -X PUT "$AUTH/auth/change-password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"currentPassword\":\"NewPass456!\",\"newPassword\":\"short\"}")
if echo "$SHORT" | grep -q '"status":"error"'; then
  echo -e "  ${GREEN}✅${NC} Change password rejects short new password"
  ((pass++))
else
  echo -e "  ${RED}❌${NC} Should reject too-short password"
  ((fail++))
fi

# Get new token with updated password
LOGIN=$(curl -s -X POST "$AUTH/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"NewPass456!\"}")
check "Login with new password" "200" "$LOGIN"

NEW_TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('accessToken',''))" 2>/dev/null)
[ -n "$NEW_TOKEN" ] && TOKEN="$NEW_TOKEN"

# ── Part 2: Device Token ────────────────────────────────────────
echo -e "\n${BOLD}Part 2: Device Token Registration${NC}"

DEV_TOKEN=$(curl -s -X POST "$USER/users/$USER_ID/device-token" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"deviceToken\":\"fake-apns-token-abc123def456\"}")
check "Register device token" "200" "$DEV_TOKEN"

NO_AUTH_DT=$(curl -s -X POST "$USER/users/$USER_ID/device-token" \
  -H "Content-Type: application/json" \
  -d "{\"deviceToken\":\"abc\"}")
if echo "$NO_AUTH_DT" | grep -q '"status":"error"'; then
  echo -e "  ${GREEN}✅${NC} Device token rejects unauthenticated request"
  ((pass++))
else
  echo -e "  ${RED}❌${NC} Should reject unauthenticated device token"
  ((fail++))
fi

# ── Part 3: Notification Preferences ───────────────────────────
echo -e "\n${BOLD}Part 3: Notification Preferences${NC}"

PREFS=$(curl -s -X PUT "$USER/users/$USER_ID/preferences" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"emailNotifications\":true,\"pushNotifications\":true}")
check "Update notification preferences (both on)" "200" "$PREFS"

PREFS_OFF=$(curl -s -X PUT "$USER/users/$USER_ID/preferences" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"emailNotifications\":false,\"pushNotifications\":false}")
check "Update notification preferences (both off)" "200" "$PREFS_OFF"

# ── Part 4: Email Notification Endpoints ───────────────────────
echo -e "\n${BOLD}Part 4: Email Notification Endpoints${NC}"

BOOK_CONF=$(curl -s -X POST "$NOTIF/notifications/send/booking-confirmation" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\":\"$TEST_EMAIL\",
    \"riderName\":\"Feature Tester\",
    \"origin\":\"123 Main St\",
    \"destination\":\"SJSU Campus\",
    \"departureTime\":\"Mar 15, 2026 at 8:00 AM\",
    \"seats\":1,
    \"amount\":5.50,
    \"bookingId\":\"test-booking-uuid-123\"
  }")
check "Booking confirmation email endpoint" "200" "$BOOK_CONF"

RECEIPT=$(curl -s -X POST "$NOTIF/notifications/send/payment-receipt" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\":\"$TEST_EMAIL\",
    \"name\":\"Feature Tester\",
    \"amount\":5.50,
    \"origin\":\"123 Main St\",
    \"destination\":\"SJSU Campus\",
    \"departureTime\":\"Mar 15, 2026 at 8:00 AM\",
    \"paymentId\":\"test-payment-uuid-456\"
  }")
check "Payment receipt email endpoint" "200" "$RECEIPT"

REMINDER=$(curl -s -X POST "$NOTIF/notifications/send/trip-reminder" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\":\"$TEST_EMAIL\",
    \"name\":\"Feature Tester\",
    \"origin\":\"123 Main St\",
    \"destination\":\"SJSU Campus\",
    \"departureTime\":\"Mar 15, 2026 at 8:00 AM\",
    \"driverName\":\"Test Driver\",
    \"vehicleInfo\":\"2022 Toyota Corolla - White\"
  }")
check "Trip reminder email endpoint" "200" "$REMINDER"

DRIVER_NOTIF=$(curl -s -X POST "$NOTIF/notifications/send/driver-new-booking" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\":\"driver@sjsu.edu\",
    \"driverName\":\"Test Driver\",
    \"riderName\":\"Feature Tester\",
    \"origin\":\"SJSU Campus\",
    \"destination\":\"456 Oak Ave\",
    \"departureTime\":\"Mar 15, 2026 at 5:00 PM\",
    \"seats\":1
  }")
check "Driver new booking notification email" "200" "$DRIVER_NOTIF"

CANCEL=$(curl -s -X POST "$NOTIF/notifications/send/cancellation" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\":\"$TEST_EMAIL\",
    \"name\":\"Feature Tester\",
    \"origin\":\"123 Main St\",
    \"destination\":\"SJSU Campus\",
    \"departureTime\":\"Mar 15, 2026 at 8:00 AM\",
    \"refundAmount\":5.50,
    \"bookingId\":\"test-booking-uuid-123\"
  }")
check "Cancellation email endpoint" "200" "$CANCEL"

# ── Part 5: Support / Report Issue ─────────────────────────────
echo -e "\n${BOLD}Part 5: Support Endpoints${NC}"

REPORT=$(curl -s -X POST "$NOTIF/support/report-issue" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\":\"$USER_ID\",
    \"email\":\"$TEST_EMAIL\",
    \"issueType\":\"Bug\",
    \"description\":\"Test issue report from automated test suite\"
  }")
check "Report issue endpoint" "200" "$REPORT"

REPORT_NO_DESC=$(curl -s -X POST "$NOTIF/support/report-issue" \
  -H "Content-Type: application/json" \
  -d "{\"issueType\":\"Bug\"}")
if echo "$REPORT_NO_DESC" | grep -q '"status":"error"'; then
  echo -e "  ${GREEN}✅${NC} Report issue rejects missing description"
  ((pass++))
else
  echo -e "  ${RED}❌${NC} Should reject missing description"
  ((fail++))
fi

# ── Summary ─────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
total=$((pass + fail))
echo -e "${BOLD}Results: ${GREEN}$pass passed${NC}, ${RED}$fail failed${NC} / $total total"
if [ $fail -eq 0 ]; then
  echo -e "${GREEN}🎉 All iOS feature tests passed!${NC}"
else
  echo -e "${YELLOW}⚠️  $fail test(s) failed — check service logs${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
exit $fail
