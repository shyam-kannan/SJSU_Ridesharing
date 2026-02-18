#!/bin/bash
# ============================================================
# LessGo Trip Service Tests (port 3003)
# Requires: Run test-auth.sh first to set environment variables
# ============================================================

set -e
BASE="http://localhost:3003"

# Load credentials from temp file if running standalone
if [ -z "$LESSGO_TEST_DRIVER_TOKEN" ]; then
    LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
    if [ -f "$LESSGO_CREDS_FILE" ]; then
        source "$LESSGO_CREDS_FILE"
    fi
fi

driverToken="${LESSGO_TEST_DRIVER_TOKEN:-$LESSGO_DRIVER_TOKEN}"
driverId="${LESSGO_TEST_DRIVER_ID:-$LESSGO_DRIVER_ID}"
riderToken="${LESSGO_TEST_RIDER_TOKEN:-$LESSGO_RIDER_TOKEN}"

if [ -z "$driverToken" ] || [ -z "$driverId" ]; then
    echo "❌ Missing test credentials. Run test-auth.sh first."
    exit 1
fi

echo ""
echo "========================================"
echo "  Trip Service Tests ($BASE)"
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
# 2. Create trip (SJSU to San Francisco)
# ----------------------------------------------------------
echo ""
echo "2. Create Trip (SJSU -> San Francisco)"
departureTime=$(date -u -d "+2 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+2d +"%Y-%m-%dT%H:%M:%SZ")

response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/trips" \
    -H "Authorization: Bearer $driverToken" \
    -H "Content-Type: application/json" \
    -d "{\"origin\":\"San Jose State University, 1 Washington Sq, San Jose, CA 95192\",\"destination\":\"San Francisco Caltrain Station, 700 4th St, San Francisco, CA 94107\",\"departure_time\":\"$departureTime\",\"seats_available\":3,\"recurrence\":\"weekdays\"}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    tripId1=$(echo "$body" | jq -r '.data.trip_id')
    origin=$(echo "$body" | jq -r '.data.origin')
    destination=$(echo "$body" | jq -r '.data.destination')
    departure=$(echo "$body" | jq -r '.data.departure_time')
    seats=$(echo "$body" | jq -r '.data.seats_available')
    status=$(echo "$body" | jq -r '.data.status')

    echo "   ✅ Trip created: $tripId1"
    echo "       Origin     : $origin"
    echo "       Destination: $destination"
    echo "       Departure  : $departure"
    echo "       Seats      : $seats"
    echo "       Status     : $status"

    originLat=$(echo "$body" | jq -r '.data.origin_point.lat // empty')
    originLng=$(echo "$body" | jq -r '.data.origin_point.lng // empty')
    if [ -n "$originLat" ] && [ -n "$originLng" ]; then
        echo "       Origin GPS : $originLat, $originLng"
    fi
else
    echo "   ❌ Create trip failed: $body"
fi

# ----------------------------------------------------------
# 3. Create second trip (SJSU to Palo Alto)
# ----------------------------------------------------------
echo ""
echo "3. Create Second Trip (SJSU -> Palo Alto)"
departureTime2=$(date -u -d "+3 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+3d +"%Y-%m-%dT%H:%M:%SZ")

response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/trips" \
    -H "Authorization: Bearer $driverToken" \
    -H "Content-Type: application/json" \
    -d "{\"origin\":\"San Jose State University, San Jose, CA\",\"destination\":\"Stanford University, 450 Serra Mall, Stanford, CA 94305\",\"departure_time\":\"$departureTime2\",\"seats_available\":2}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    tripId2=$(echo "$body" | jq -r '.data.trip_id')
    destination=$(echo "$body" | jq -r '.data.destination')
    seats=$(echo "$body" | jq -r '.data.seats_available')

    echo "   ✅ Trip created: $tripId2"
    echo "       Destination: $destination"
    echo "       Seats      : $seats"
else
    echo "   ❌ Create trip 2 failed"
fi

# ----------------------------------------------------------
# 4. Rider tries to create trip (expect 403)
# ----------------------------------------------------------
echo ""
echo "4. Rider Creates Trip (expect 403)"
if [ -n "$riderToken" ]; then
    departureTime3=$(date -u -d "+1 day" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+1d +"%Y-%m-%dT%H:%M:%SZ")

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/trips" \
        -H "Authorization: Bearer $riderToken" \
        -H "Content-Type: application/json" \
        -d "{\"origin\":\"SJSU\",\"destination\":\"Downtown\",\"departure_time\":\"$departureTime3\",\"seats_available\":2}")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "403" ]; then
        echo "   ✅ Rider correctly rejected (HTTP $http_code)"
    else
        echo "   ❌ Should have returned 403"
    fi
else
    echo "   ⚠️  Skipped: no rider token"
fi

# ----------------------------------------------------------
# 5. Get trip by ID
# ----------------------------------------------------------
echo ""
echo "5. Get Trip By ID"
if [ -n "$tripId1" ]; then
    response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/trips/$tripId1")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        origin=$(echo "$body" | jq -r '.data.origin')
        destination=$(echo "$body" | jq -r '.data.destination')
        driverName=$(echo "$body" | jq -r '.data.driver.name')
        status=$(echo "$body" | jq -r '.data.status')

        echo "   ✅ Trip: $origin -> $destination"
        echo "       Driver: $driverName"
        echo "       Status: $status"
    else
        echo "   ❌ Get trip failed"
    fi
else
    echo "   ⚠️  Skipped: no trip ID"
fi

# ----------------------------------------------------------
# 6. Search trips near SJSU
# ----------------------------------------------------------
echo ""
echo "6. Search Trips Near SJSU (geospatial)"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/trips/search?origin_lat=37.3352&origin_lng=-121.8811&radius_meters=10000&min_seats=1")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    count=$(echo "$body" | jq -r '.data.total')
    echo "   ✅ Found $count trip(s) within 10km of SJSU"

    trips=$(echo "$body" | jq -r '.data.trips[]? | "       - \(.origin) -> \(.destination) | seats: \(.seats_available)"')
    if [ -n "$trips" ]; then
        echo "$trips"
    fi
else
    echo "   ❌ Search failed"
fi

# ----------------------------------------------------------
# 7. List all trips
# ----------------------------------------------------------
echo ""
echo "7. List All Trips"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/trips")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    total=$(echo "$body" | jq -r '.data.total')
    echo "   ✅ Total trips: $total"
else
    echo "   ❌ List trips failed"
fi

# ----------------------------------------------------------
# 8. List driver's trips
# ----------------------------------------------------------
echo ""
echo "8. List Driver's Trips"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/trips?driver_id=$driverId")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    total=$(echo "$body" | jq -r '.data.total')
    echo "   ✅ Driver has $total trip(s)"
else
    echo "   ❌ List driver trips failed"
fi

# ----------------------------------------------------------
# 9. Update trip
# ----------------------------------------------------------
echo ""
echo "9. Update Trip (change seats)"
if [ -n "$tripId1" ]; then
    response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/trips/$tripId1" \
        -H "Authorization: Bearer $driverToken" \
        -H "Content-Type: application/json" \
        -d '{"seats_available":4}')
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        seats=$(echo "$body" | jq -r '.data.seats_available')
        echo "   ✅ Updated seats to: $seats"
    else
        echo "   ❌ Update trip failed"
    fi
else
    echo "   ⚠️  Skipped: no trip ID"
fi

# ----------------------------------------------------------
# 10. Cancel second trip
# ----------------------------------------------------------
echo ""
echo "10. Cancel Trip"
if [ -n "$tripId2" ]; then
    response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/trips/$tripId2" \
        -H "Authorization: Bearer $driverToken")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        status=$(echo "$body" | jq -r '.data.status')
        echo "   ✅ Trip cancelled. Status: $status"
    else
        echo "   ❌ Cancel trip failed"
    fi
else
    echo "   ⚠️  Skipped: no trip ID"
fi

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo ""
echo "========================================"
echo "  Trip Service Tests Complete"
echo "========================================"
echo ""

# Export trip ID for downstream tests
export LESSGO_TEST_TRIP_ID="$tripId1"

# Update credentials file with trip ID
LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
if [ -f "$LESSGO_CREDS_FILE" ]; then
    echo "export LESSGO_TEST_TRIP_ID=\"$tripId1\"" >> "$LESSGO_CREDS_FILE"
fi
