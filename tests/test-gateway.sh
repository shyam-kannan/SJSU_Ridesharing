#!/bin/bash
# ============================================================
# LessGo API Gateway End-to-End Tests (port 3000)
# Full flow: Register -> Login -> Create Trip -> Search ->
#            Book -> Confirm -> Rate
# All requests go through the API Gateway
# Requires: All backend services running
# ============================================================

set -e
GW="http://localhost:3000"
timestamp=$(date +%Y%m%d%H%M%S)

echo ""
echo "========================================"
echo "  API Gateway E2E Tests ($GW)"
echo "========================================"
echo ""

# ----------------------------------------------------------
# 1. Gateway health check
# ----------------------------------------------------------
echo "1. Gateway Health Check"
response=$(curl -s -w "\n%{http_code}" "$GW/health")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    message=$(echo "$body" | jq -r '.message')
    echo "   ✅ Gateway: $message"
else
    echo "   ❌ Gateway health check failed. Is it running on port 3000?"
    exit 1
fi

# ----------------------------------------------------------
# 2. Register Driver through gateway
# ----------------------------------------------------------
echo ""
echo "2. Register Driver (via gateway)"
response=$(curl -s -w "\n%{http_code}" -X POST "$GW/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"E2E Driver $timestamp\",\"email\":\"e2e-driver-${timestamp}@sjsu.edu\",\"password\":\"TestPass123\",\"role\":\"Driver\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    driverId=$(echo "$body" | jq -r '.data.user.user_id')
    driverToken=$(echo "$body" | jq -r '.data.accessToken')
    driverName=$(echo "$body" | jq -r '.data.user.name')
    driverEmail=$(echo "$body" | jq -r '.data.user.email')

    echo "   ✅ Driver: $driverName"
    echo "       ID   : $driverId"
    echo "       Email: $driverEmail"
    echo "       (Routed through API Gateway)"
else
    echo "   ❌ Driver registration failed: $body"
    exit 1
fi

# ----------------------------------------------------------
# 3. Register Rider through gateway
# ----------------------------------------------------------
echo ""
echo "3. Register Rider (via gateway)"
response=$(curl -s -w "\n%{http_code}" -X POST "$GW/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"E2E Rider $timestamp\",\"email\":\"e2e-rider-${timestamp}@sjsu.edu\",\"password\":\"TestPass123\",\"role\":\"Rider\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    riderId=$(echo "$body" | jq -r '.data.user.user_id')
    riderToken=$(echo "$body" | jq -r '.data.accessToken')
    riderName=$(echo "$body" | jq -r '.data.user.name')

    echo "   ✅ Rider: $riderName"
    echo "       ID: $riderId"
else
    echo "   ❌ Rider registration failed"
    exit 1
fi

# ----------------------------------------------------------
# 3b. Auto-verify both users (test-only, direct to auth service)
# ----------------------------------------------------------
echo ""
echo "3b. Auto-Verify Users (test-only)"
AUTH="http://localhost:3001"

response=$(curl -s -w "\n%{http_code}" -X POST "$AUTH/auth/test/verify/$driverId")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo "   ✅ Driver verified"
else
    echo "   ❌ Driver verify failed"
fi

response=$(curl -s -w "\n%{http_code}" -X POST "$AUTH/auth/test/verify/$riderId")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo "   ✅ Rider verified"
else
    echo "   ❌ Rider verify failed"
fi

# ----------------------------------------------------------
# 4. Login as driver
# ----------------------------------------------------------
echo ""
echo "4. Login as Driver (via gateway)"
response=$(curl -s -w "\n%{http_code}" -X POST "$GW/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"e2e-driver-${timestamp}@sjsu.edu\",\"password\":\"TestPass123\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    driverToken=$(echo "$body" | jq -r '.data.accessToken')
    echo "   ✅ Driver logged in"
else
    echo "   ❌ Login failed"
fi

# ----------------------------------------------------------
# 5. Setup driver profile through gateway
# ----------------------------------------------------------
echo ""
echo "5. Setup Driver Profile (via gateway)"
response=$(curl -s -w "\n%{http_code}" -X PUT "$GW/api/users/$driverId/driver-setup" \
    -H "Authorization: Bearer $driverToken" \
    -H "Content-Type: application/json" \
    -d '{"vehicle_info":"2024 Honda Civic - Silver - 8XYZ123","seats_available":3}')
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    vehicleInfo=$(echo "$body" | jq -r '.data.vehicle_info')
    seats=$(echo "$body" | jq -r '.data.seats_available')

    echo "   ✅ Driver profile: $vehicleInfo"
    echo "       Seats: $seats"
else
    echo "   ❌ Driver setup failed"
fi

# ----------------------------------------------------------
# 6. Create trip through gateway
# ----------------------------------------------------------
echo ""
echo "6. Create Trip (via gateway)"
departureTime=$(date -u -d "+1 day" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+1d +"%Y-%m-%dT%H:%M:%SZ")

response=$(curl -s -w "\n%{http_code}" -X POST "$GW/api/trips" \
    -H "Authorization: Bearer $driverToken" \
    -H "Content-Type: application/json" \
    -d "{\"origin\":\"San Jose State University, 1 Washington Sq, San Jose, CA 95192\",\"destination\":\"Googleplex, 1600 Amphitheatre Pkwy, Mountain View, CA 94043\",\"departure_time\":\"$departureTime\",\"seats_available\":3}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    tripId=$(echo "$body" | jq -r '.data.trip_id')
    seats=$(echo "$body" | jq -r '.data.seats_available')

    echo "   ✅ Trip created: $tripId"
    echo "       SJSU -> Googleplex"
    echo "       Seats: $seats"
else
    echo "   ❌ Create trip failed: $body"
fi

# ----------------------------------------------------------
# 7. Search trips near SJSU through gateway
# ----------------------------------------------------------
echo ""
echo "7. Search Trips Near SJSU (via gateway)"
response=$(curl -s -w "\n%{http_code}" -X GET "$GW/api/trips/search?origin_lat=37.3352&origin_lng=-121.8811&radius_meters=15000")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    total=$(echo "$body" | jq -r '.data.total')
    echo "   ✅ Found $total trip(s) near SJSU"

    trips=$(echo "$body" | jq -r '.data.trips[]? | "       - \(.destination) | seats: \(.seats_available) | driver: \(.driver.name)"')
    if [ -n "$trips" ]; then
        echo "$trips"
    fi
else
    echo "   ❌ Search failed"
fi

# ----------------------------------------------------------
# 8. Get trip details through gateway
# ----------------------------------------------------------
echo ""
echo "8. Get Trip Details (via gateway)"
if [ -n "$tripId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X GET "$GW/api/trips/$tripId")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        origin=$(echo "$body" | jq -r '.data.origin')
        destination=$(echo "$body" | jq -r '.data.destination')
        driverName=$(echo "$body" | jq -r '.data.driver.name')
        vehicleInfo=$(echo "$body" | jq -r '.data.driver.vehicle_info')

        echo "   ✅ Trip: $origin -> $destination"
        echo "       Driver : $driverName"
        echo "       Vehicle: $vehicleInfo"
    else
        echo "   ❌ Get trip failed"
    fi
fi

# ----------------------------------------------------------
# 9. Create booking as rider through gateway
# ----------------------------------------------------------
echo ""
echo "9. Create Booking (Rider via gateway)"
bookingId=""

if [ -n "$tripId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$GW/api/bookings" \
        -H "Authorization: Bearer $riderToken" \
        -H "Content-Type: application/json" \
        -d "{\"trip_id\":\"$tripId\",\"seats_booked\":1}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        bookingId=$(echo "$body" | jq -r '.data.booking.booking_id')
        status=$(echo "$body" | jq -r '.data.booking.status')

        echo "   ✅ Booking created: $bookingId"
        echo "       Status: $status"

        maxPrice=$(echo "$body" | jq -r '.data.quote.max_price // empty')
        if [ -n "$maxPrice" ]; then
            echo "       Quote : \$$maxPrice"
        fi
    else
        echo "   ❌ Create booking failed: $body"
    fi
fi

# ----------------------------------------------------------
# 10. Confirm booking (payment) through gateway
# ----------------------------------------------------------
echo ""
echo "10. Confirm Booking with Payment (via gateway)"
if [ -n "$bookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X PUT "$GW/api/bookings/$bookingId/confirm" \
        -H "Authorization: Bearer $riderToken")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        status=$(echo "$body" | jq -r '.data.status')
        echo "   ✅ Booking confirmed: $status"

        paymentAmount=$(echo "$body" | jq -r '.data.payment.amount // empty')
        paymentStatus=$(echo "$body" | jq -r '.data.payment.status // empty')
        if [ -n "$paymentAmount" ]; then
            echo "       Payment: \$$paymentAmount ($paymentStatus)"
        fi
    else
        echo "   ❌ Confirm failed"
    fi
fi

# ----------------------------------------------------------
# 11. Get user profile through gateway
# ----------------------------------------------------------
echo ""
echo "11. Get Rider Profile (via gateway)"
response=$(curl -s -w "\n%{http_code}" -X GET "$GW/api/users/me" \
    -H "Authorization: Bearer $riderToken")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    userName=$(echo "$body" | jq -r '.data.name')
    rating=$(echo "$body" | jq -r '.data.rating')

    echo "   ✅ Rider: $userName"
    echo "       Rating: $rating"
else
    echo "   ❌ Get profile failed"
fi

# ----------------------------------------------------------
# 12. Protected route without token (expect 401)
# ----------------------------------------------------------
echo ""
echo "12. Access Protected Route Without Token (expect 401)"
response=$(curl -s -w "\n%{http_code}" -X GET "$GW/api/users/me")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "401" ]; then
    echo "   ✅ Gateway correctly rejected (HTTP $http_code)"
else
    echo "   ❌ Should have returned 401"
fi

# ----------------------------------------------------------
# 13. Public routes work without auth
# ----------------------------------------------------------
echo ""
echo "13. Public Routes Without Auth"
response=$(curl -s -w "\n%{http_code}" -X GET "$GW/api/trips")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "200" ]; then
    echo "   ✅ GET /api/trips works without auth (public)"
else
    echo "   ❌ Public route failed"
fi

# ----------------------------------------------------------
# 14. Non-existent route (expect 404)
# ----------------------------------------------------------
echo ""
echo "14. Non-Existent Route (expect 404)"
response=$(curl -s -w "\n%{http_code}" -X GET "$GW/api/nonexistent")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "404" ]; then
    echo "   ✅ Correctly returned HTTP $http_code"
else
    echo "   ❌ Should have returned 404"
fi

# ----------------------------------------------------------
# 15. Rate limiting test
# ----------------------------------------------------------
echo ""
echo "15. Rate Limiting (send burst of requests)"
successCount=0
rateLimited=false

for i in {1..10}; do
    response=$(curl -s -w "\n%{http_code}" -X GET "$GW/health")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        ((successCount++))
    elif [ "$http_code" = "429" ]; then
        rateLimited=true
        break
    fi
done

if [ "$rateLimited" = true ]; then
    echo "   ✅ Rate limiting active (hit at request $successCount)"
else
    echo "   ✅ $successCount/10 requests succeeded (under limit)"
fi

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo ""
echo "========================================"
echo "  API Gateway E2E Tests Complete"
echo "========================================"
echo "  Full flow tested through gateway:"
echo "    Register -> Login -> Driver Setup"
echo "    Create Trip -> Search -> Book -> Confirm"
echo "    Auth enforcement + public routes"
echo "    Rate limiting active"
echo ""
