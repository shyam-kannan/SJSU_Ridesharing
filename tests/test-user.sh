#!/bin/bash
# ============================================================
# LessGo User Service Tests (port 3002)
# Requires: Run test-auth.sh first to set environment variables
# ============================================================

set -e
BASE="http://localhost:3002"

# Load credentials from temp file if running standalone
if [ -z "$LESSGO_TEST_RIDER_TOKEN" ]; then
    LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
    if [ -f "$LESSGO_CREDS_FILE" ]; then
        source "$LESSGO_CREDS_FILE"
    fi
fi

# Grab credentials from auth tests or use defaults
riderToken="${LESSGO_TEST_RIDER_TOKEN:-$LESSGO_RIDER_TOKEN}"
riderId="${LESSGO_TEST_RIDER_ID:-$LESSGO_RIDER_ID}"
driverToken="${LESSGO_TEST_DRIVER_TOKEN:-$LESSGO_DRIVER_TOKEN}"
driverId="${LESSGO_TEST_DRIVER_ID:-$LESSGO_DRIVER_ID}"

if [ -z "$riderToken" ] || [ -z "$riderId" ]; then
    echo "❌ Missing test credentials. Run test-auth.sh first."
    exit 1
fi

echo ""
echo "========================================"
echo "  User Service Tests ($BASE)"
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
# 2. Get current user profile (GET /users/me)
# ----------------------------------------------------------
echo ""
echo "2. Get Current User Profile (/users/me)"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/users/me" \
    -H "Authorization: Bearer $riderToken")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    userName=$(echo "$body" | jq -r '.data.name')
    userEmail=$(echo "$body" | jq -r '.data.email')
    userRole=$(echo "$body" | jq -r '.data.role')
    rating=$(echo "$body" | jq -r '.data.rating')
    sjsuStatus=$(echo "$body" | jq -r '.data.sjsu_id_status')

    echo "   ✅ Profile: $userName ($userEmail)"
    echo "       Role   : $userRole"
    echo "       Rating : $rating"
    echo "       SJSU   : $sjsuStatus"
else
    echo "   ❌ Get /me failed"
fi

# ----------------------------------------------------------
# 3. Get user by ID (GET /users/:id)
# ----------------------------------------------------------
echo ""
echo "3. Get User By ID"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/users/$riderId")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    userName=$(echo "$body" | jq -r '.data.name')
    userEmail=$(echo "$body" | jq -r '.data.email')
    createdAt=$(echo "$body" | jq -r '.data.created_at')

    echo "   ✅ User: $userName ($userEmail)"
    echo "       Created: $createdAt"
else
    echo "   ❌ Get user failed"
fi

# ----------------------------------------------------------
# 4. Get non-existent user (expect 404)
# ----------------------------------------------------------
echo ""
echo "4. Get Non-Existent User (expect 404)"
fakeId="00000000-0000-0000-0000-000000000000"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/users/$fakeId")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "404" ]; then
    echo "   ✅ Correctly returned HTTP $http_code"
else
    echo "   ❌ Should have returned 404"
fi

# ----------------------------------------------------------
# 5. Update user profile (PUT /users/:id)
# ----------------------------------------------------------
echo ""
echo "5. Update User Profile"
response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/users/$riderId" \
    -H "Authorization: Bearer $riderToken" \
    -H "Content-Type: application/json" \
    -d '{"name":"Updated Rider Name"}')
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    userName=$(echo "$body" | jq -r '.data.name')
    echo "   ✅ Updated name: $userName"
else
    echo "   ❌ Update failed"
fi

# ----------------------------------------------------------
# 6. Update another user's profile (expect 403)
# ----------------------------------------------------------
echo ""
echo "6. Update Another User's Profile (expect 403)"
fakeId="00000000-0000-0000-0000-000000000001"
response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/users/$fakeId" \
    -H "Authorization: Bearer $riderToken" \
    -H "Content-Type: application/json" \
    -d '{"name":"Hacker"}')
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "403" ]; then
    echo "   ✅ Correctly rejected (HTTP $http_code)"
else
    echo "   ❌ Should have returned 403"
fi

# ----------------------------------------------------------
# 7. Setup driver profile (PUT /users/:id/driver-setup)
# ----------------------------------------------------------
echo ""
echo "7. Setup Driver Profile"
if [ -n "$driverToken" ] && [ -n "$driverId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/users/$driverId/driver-setup" \
        -H "Authorization: Bearer $driverToken" \
        -H "Content-Type: application/json" \
        -d '{"vehicle_info":"2023 Tesla Model 3 - White - License ABC1234","seats_available":4}')
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        vehicleInfo=$(echo "$body" | jq -r '.data.vehicle_info')
        seats=$(echo "$body" | jq -r '.data.seats_available')
        userRole=$(echo "$body" | jq -r '.data.role')

        echo "   ✅ Driver setup: $vehicleInfo"
        echo "       Seats: $seats"
        echo "       Role : $userRole"
    else
        echo "   ❌ Driver setup failed"
    fi
else
    echo "   ⚠️  Skipped: no driver credentials"
fi

# ----------------------------------------------------------
# 8. Get user ratings (GET /users/:id/ratings)
# ----------------------------------------------------------
echo ""
echo "8. Get User Ratings"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/users/$riderId/ratings")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    totalRatings=$(echo "$body" | jq -r '.data.total_ratings')
    avgRating=$(echo "$body" | jq -r '.data.average_rating')

    echo "   ✅ Total ratings : $totalRatings"
    echo "       Average: $avgRating"
else
    echo "   ❌ Get ratings failed"
fi

# ----------------------------------------------------------
# 9. Get user stats (GET /users/:id/stats)
# ----------------------------------------------------------
echo ""
echo "9. Get User Statistics"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/users/$riderId/stats")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    totalRatings=$(echo "$body" | jq -r '.data.total_ratings')
    avgRating=$(echo "$body" | jq -r '.data.average_rating')
    totalBookings=$(echo "$body" | jq -r '.data.total_bookings_as_rider')

    echo "   ✅ Stats retrieved"
    echo "       Total ratings    : $totalRatings"
    echo "       Average rating   : $avgRating"
    echo "       Bookings as rider: $totalBookings"
else
    echo "   ❌ Get stats failed"
fi

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo ""
echo "========================================"
echo "  User Service Tests Complete"
echo "========================================"
echo ""
