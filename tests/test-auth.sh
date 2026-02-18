#!/bin/bash
# ============================================================
# LessGo Auth Service Tests (port 3001)
# ============================================================

set -e
BASE="http://localhost:3001"
timestamp=$(date +%Y%m%d%H%M%S)
testEmail="testuser-${timestamp}@sjsu.edu"
testPassword="TestPass123"
testName="Test User ${timestamp}"

echo ""
echo "========================================"
echo "  Auth Service Tests ($BASE)"
echo "========================================"
echo ""

# ----------------------------------------------------------
# 1. Health check
# ----------------------------------------------------------
echo "1. Health Check"
response=$(curl -s -w "\n%{http_code}" "$BASE/health")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    message=$(echo "$body" | jq -r '.message')
    echo "   ✅ Health: $message"
else
    echo "   ❌ Health check failed"
    exit 1
fi

# ----------------------------------------------------------
# 2. Register new user (Rider)
# ----------------------------------------------------------
echo ""
echo "2. Register New User (Rider)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$testName\",\"email\":\"$testEmail\",\"password\":\"$testPassword\",\"role\":\"Rider\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    userId=$(echo "$body" | jq -r '.data.user.user_id')
    accessToken=$(echo "$body" | jq -r '.data.accessToken')
    refreshToken=$(echo "$body" | jq -r '.data.refreshToken')
    userName=$(echo "$body" | jq -r '.data.user.name')
    userEmail=$(echo "$body" | jq -r '.data.user.email')
    userRole=$(echo "$body" | jq -r '.data.user.role')
    sjsuStatus=$(echo "$body" | jq -r '.data.user.sjsu_id_status')

    echo "   ✅ Registered: $userName ($userEmail)"
    echo "       User ID : $userId"
    echo "       Role    : $userRole"
    echo "       SJSU    : $sjsuStatus"
else
    echo "   ❌ Register failed: $body"
    exit 1
fi

# ----------------------------------------------------------
# 2b. Auto-verify Rider (test-only endpoint)
# ----------------------------------------------------------
echo ""
echo "2b. Auto-Verify Rider (test-only)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/test/verify/$userId")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    sjsuStatus=$(echo "$body" | jq -r '.data.sjsu_id_status')
    echo "   ✅ Rider verified: sjsu_id_status=$sjsuStatus"
else
    echo "   ❌ Verify rider failed"
fi

# ----------------------------------------------------------
# 3. Register duplicate (expect 409)
# ----------------------------------------------------------
echo ""
echo "3. Register Duplicate (expect error)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$testName\",\"email\":\"$testEmail\",\"password\":\"$testPassword\",\"role\":\"Rider\"}")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "409" ] || [ "$http_code" = "400" ]; then
    echo "   ✅ Duplicate correctly rejected (HTTP $http_code)"
else
    echo "   ❌ Should have returned 409"
fi

# ----------------------------------------------------------
# 4. Login
# ----------------------------------------------------------
echo ""
echo "4. Login"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$testEmail\",\"password\":\"$testPassword\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    accessToken=$(echo "$body" | jq -r '.data.accessToken')
    refreshToken=$(echo "$body" | jq -r '.data.refreshToken')
    userName=$(echo "$body" | jq -r '.data.user.name')

    echo "   ✅ Login successful: $userName"
    echo "       Access token : ${accessToken:0:30}..."
    echo "       Refresh token: ${refreshToken:0:30}..."
else
    echo "   ❌ Login failed"
    exit 1
fi

# ----------------------------------------------------------
# 5. Login with wrong password (expect 401)
# ----------------------------------------------------------
echo ""
echo "5. Login with Wrong Password (expect error)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$testEmail\",\"password\":\"WrongPassword999\"}")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "401" ]; then
    echo "   ✅ Wrong password correctly rejected (HTTP $http_code)"
else
    echo "   ❌ Should have returned 401"
fi

# ----------------------------------------------------------
# 6. Verify token
# ----------------------------------------------------------
echo ""
echo "6. Verify Token"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/auth/verify" \
    -H "Authorization: Bearer $accessToken")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    valid=$(echo "$body" | jq -r '.data.valid')
    userEmail=$(echo "$body" | jq -r '.data.user.email')
    echo "   ✅ Token valid: $valid, user: $userEmail"
else
    echo "   ❌ Verify failed"
fi

# ----------------------------------------------------------
# 7. Refresh token
# ----------------------------------------------------------
echo ""
echo "7. Refresh Token"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refreshToken\":\"$refreshToken\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    newAccessToken=$(echo "$body" | jq -r '.data.accessToken')
    echo "   ✅ New access token: ${newAccessToken:0:30}..."
else
    echo "   ❌ Refresh failed"
fi

# ----------------------------------------------------------
# 8. Get current user (/auth/me)
# ----------------------------------------------------------
echo ""
echo "8. Get Current User (/auth/me)"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/auth/me" \
    -H "Authorization: Bearer $accessToken")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    userName=$(echo "$body" | jq -r '.data.name')
    userEmail=$(echo "$body" | jq -r '.data.email')
    rating=$(echo "$body" | jq -r '.data.rating')
    echo "   ✅ Current user: $userName ($userEmail)"
    echo "       Rating: $rating"
else
    echo "   ❌ Get /me failed"
fi

# ----------------------------------------------------------
# 9. Access protected route without token (expect 401)
# ----------------------------------------------------------
echo ""
echo "9. Access Without Token (expect 401)"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/auth/verify")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "401" ]; then
    echo "   ✅ Correctly rejected without token (HTTP $http_code)"
else
    echo "   ❌ Should have returned 401"
fi

# ----------------------------------------------------------
# 10. Logout
# ----------------------------------------------------------
echo ""
echo "10. Logout"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/logout" \
    -H "Authorization: Bearer $accessToken")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    message=$(echo "$body" | jq -r '.message')
    echo "   ✅ $message"
else
    echo "   ❌ Logout failed"
fi

# ----------------------------------------------------------
# 11. Register Driver (for other tests)
# ----------------------------------------------------------
echo ""
echo "11. Register Driver User"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Driver $timestamp\",\"email\":\"driver-${timestamp}@sjsu.edu\",\"password\":\"$testPassword\",\"role\":\"Driver\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    driverUserId=$(echo "$body" | jq -r '.data.user.user_id')
    driverToken=$(echo "$body" | jq -r '.data.accessToken')
    driverName=$(echo "$body" | jq -r '.data.user.name')

    echo "   ✅ Driver registered: $driverName"
    echo "       Driver ID: $driverUserId"
else
    echo "   ❌ Driver registration failed"
fi

# ----------------------------------------------------------
# 11b. Auto-verify Driver (test-only endpoint)
# ----------------------------------------------------------
echo ""
echo "11b. Auto-Verify Driver (test-only)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/test/verify/$driverUserId")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    sjsuStatus=$(echo "$body" | jq -r '.data.sjsu_id_status')
    echo "   ✅ Driver verified: sjsu_id_status=$sjsuStatus"
else
    echo "   ❌ Verify driver failed"
fi

# ----------------------------------------------------------
# 12. Re-login both users (get tokens with verified status)
# ----------------------------------------------------------
echo ""
echo "12. Re-login Users (get verified tokens)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$testEmail\",\"password\":\"$testPassword\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    accessToken=$(echo "$body" | jq -r '.data.accessToken')
    refreshToken=$(echo "$body" | jq -r '.data.refreshToken')
    echo "   ✅ Rider re-logged in (verified token)"
else
    echo "   ❌ Rider re-login failed"
fi

response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"driver-${timestamp}@sjsu.edu\",\"password\":\"$testPassword\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    driverToken=$(echo "$body" | jq -r '.data.accessToken')
    echo "   ✅ Driver re-logged in (verified token)"
else
    echo "   ❌ Driver re-login failed"
fi

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo ""
echo "========================================"
echo "  Auth Tests Complete"
echo "========================================"
echo "  Rider  : $testEmail / $testPassword"
echo "  Driver : driver-${timestamp}@sjsu.edu / $testPassword"
echo "  Rider Token  : ${accessToken:0:20}..."
echo "  Driver Token : ${driverToken:0:20}..."
echo ""

# Export for downstream scripts
export LESSGO_TEST_RIDER_EMAIL="$testEmail"
export LESSGO_TEST_RIDER_PASSWORD="$testPassword"
export LESSGO_TEST_RIDER_TOKEN="$accessToken"
export LESSGO_TEST_RIDER_ID="$userId"
export LESSGO_TEST_DRIVER_EMAIL="driver-${timestamp}@sjsu.edu"
export LESSGO_TEST_DRIVER_TOKEN="$driverToken"
export LESSGO_TEST_DRIVER_ID="$driverUserId"
export LESSGO_TEST_TIMESTAMP="$timestamp"

# Save to temp file for cross-script usage
LESSGO_CREDS_FILE="/tmp/lessgo-test-credentials-$$.sh"
cat > "$LESSGO_CREDS_FILE" << EOF
export LESSGO_TEST_RIDER_EMAIL="$testEmail"
export LESSGO_TEST_RIDER_PASSWORD="$testPassword"
export LESSGO_TEST_RIDER_TOKEN="$accessToken"
export LESSGO_TEST_RIDER_ID="$userId"
export LESSGO_TEST_DRIVER_EMAIL="driver-${timestamp}@sjsu.edu"
export LESSGO_TEST_DRIVER_TOKEN="$driverToken"
export LESSGO_TEST_DRIVER_ID="$driverUserId"
export LESSGO_TEST_TIMESTAMP="$timestamp"
EOF

echo "  Credentials saved to: $LESSGO_CREDS_FILE"
