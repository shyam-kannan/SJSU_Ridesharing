#!/bin/bash
# ============================================================
# LessGo Booking Service Tests (port 3004)
# Requires: test-auth.sh and test-trip.sh run first
# Also requires: Cost Calculation Service (port 3009) running
# ============================================================

set -e
BASE="http://localhost:3004"

# Load credentials from temp file if running standalone
if [ -z "$LESSGO_TEST_RIDER_TOKEN" ]; then
    LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
    if [ -f "$LESSGO_CREDS_FILE" ]; then
        source "$LESSGO_CREDS_FILE"
    fi
fi

riderToken="${LESSGO_TEST_RIDER_TOKEN:-$LESSGO_RIDER_TOKEN}"
riderId="${LESSGO_TEST_RIDER_ID:-$LESSGO_RIDER_ID}"
driverToken="${LESSGO_TEST_DRIVER_TOKEN:-$LESSGO_DRIVER_TOKEN}"
driverId="${LESSGO_TEST_DRIVER_ID:-$LESSGO_DRIVER_ID}"
tripId="${LESSGO_TEST_TRIP_ID:-$LESSGO_TRIP_ID}"

if [ -z "$riderToken" ] || [ -z "$tripId" ]; then
    echo "❌ Missing test credentials or trip ID. Run test-auth.sh and test-trip.sh first."
    exit 1
fi

echo ""
echo "========================================"
echo "  Booking Service Tests ($BASE)"
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
# 2. Create booking
# ----------------------------------------------------------
echo ""
echo "2. Create Booking (Rider books trip)"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/bookings" \
    -H "Authorization: Bearer $riderToken" \
    -H "Content-Type: application/json" \
    -d "{\"trip_id\":\"$tripId\",\"seats_booked\":1}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    bookingId=$(echo "$body" | jq -r '.data.booking.booking_id')
    bookingStatus=$(echo "$body" | jq -r '.data.booking.status')
    seatsBooked=$(echo "$body" | jq -r '.data.booking.seats_booked')

    echo "   ✅ Booking created: $bookingId"
    echo "       Status    : $bookingStatus"
    echo "       Seats     : $seatsBooked"

    maxPrice=$(echo "$body" | jq -r '.data.quote.max_price // empty')
    if [ -n "$maxPrice" ]; then
        echo "       Max Price : \$$maxPrice"
    fi
else
    echo "   ❌ Create booking failed: $body"
fi

# ----------------------------------------------------------
# 3. Driver tries to book own trip (expect error)
# ----------------------------------------------------------
echo ""
echo "3. Driver Books Own Trip (expect error)"
if [ -n "$driverToken" ]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/bookings" \
        -H "Authorization: Bearer $driverToken" \
        -H "Content-Type: application/json" \
        -d "{\"trip_id\":\"$tripId\",\"seats_booked\":1}")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "400" ] || [ "$http_code" = "403" ]; then
        echo "   ✅ Driver correctly rejected (HTTP $http_code)"
    else
        echo "   ❌ Should have been rejected"
    fi
else
    echo "   ⚠️  Skipped: no driver token"
fi

# ----------------------------------------------------------
# 4. Get booking details
# ----------------------------------------------------------
echo ""
echo "4. Get Booking Details"
if [ -n "$bookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/bookings/$bookingId")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        status=$(echo "$body" | jq -r '.data.status')
        tripOrigin=$(echo "$body" | jq -r '.data.trip.origin')
        tripDest=$(echo "$body" | jq -r '.data.trip.destination')
        riderName=$(echo "$body" | jq -r '.data.rider.name')

        echo "   ✅ Booking details retrieved"
        echo "       Status      : $status"
        echo "       Trip        : $tripOrigin -> $tripDest"
        echo "       Rider       : $riderName"

        quotePrice=$(echo "$body" | jq -r '.data.quote.max_price // empty')
        if [ -n "$quotePrice" ]; then
            echo "       Quote       : \$$quotePrice"
        fi

        paymentStatus=$(echo "$body" | jq -r '.data.payment.status // empty')
        paymentAmount=$(echo "$body" | jq -r '.data.payment.amount // empty')
        if [ -n "$paymentStatus" ]; then
            echo "       Payment     : $paymentStatus (\$$paymentAmount)"
        fi
    else
        echo "   ❌ Get booking failed"
    fi
else
    echo "   ⚠️  Skipped: no booking ID"
fi

# ----------------------------------------------------------
# 5. List rider's bookings
# ----------------------------------------------------------
echo ""
echo "5. List Rider's Bookings"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/bookings" \
    -H "Authorization: Bearer $riderToken")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    total=$(echo "$body" | jq -r '.data.total')
    echo "   ✅ Rider has $total booking(s)"

    bookings=$(echo "$body" | jq -r '.data.bookings[]? | "       - \(.booking_id[:8])... | \(.status) | \(.trip.destination)"')
    if [ -n "$bookings" ]; then
        echo "$bookings"
    fi
else
    echo "   ❌ List bookings failed"
fi

# ----------------------------------------------------------
# 6. List driver's bookings
# ----------------------------------------------------------
echo ""
echo "6. List Driver's Bookings (as_driver=true)"
if [ -n "$driverToken" ]; then
    response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/bookings?as_driver=true" \
        -H "Authorization: Bearer $driverToken")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        total=$(echo "$body" | jq -r '.data.total')
        echo "   ✅ Driver sees $total booking(s)"
    else
        echo "   ❌ List driver bookings failed"
    fi
else
    echo "   ⚠️  Skipped: no driver token"
fi

# ----------------------------------------------------------
# 7. Confirm booking (triggers payment)
# ----------------------------------------------------------
echo ""
echo "7. Confirm Booking (creates payment)"
if [ -n "$bookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/bookings/$bookingId/confirm" \
        -H "Authorization: Bearer $riderToken")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        status=$(echo "$body" | jq -r '.data.status')
        echo "   ✅ Booking confirmed: $status"

        paymentId=$(echo "$body" | jq -r '.data.payment.payment_id // empty')
        paymentStatus=$(echo "$body" | jq -r '.data.payment.status // empty')
        paymentAmount=$(echo "$body" | jq -r '.data.payment.amount // empty')

        if [ -n "$paymentId" ]; then
            echo "       Payment ID    : $paymentId"
            echo "       Payment Status: $paymentStatus"
            echo "       Amount        : \$$paymentAmount"
            export LESSGO_TEST_PAYMENT_ID="$paymentId"
        fi
    else
        echo "   ❌ Confirm failed: $body"
        echo "       Note: Payment Service (3005) and Cost Service (3009) must be running"
    fi
else
    echo "   ⚠️  Skipped: no booking ID"
fi

# ----------------------------------------------------------
# 8. Cancel booking (with refund)
# ----------------------------------------------------------
echo ""
echo "8. Cancel Booking"
if [ -n "$bookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/bookings/$bookingId/cancel" \
        -H "Authorization: Bearer $riderToken")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        status=$(echo "$body" | jq -r '.data.status')
        echo "   ✅ Booking cancelled: $status"
    else
        echo "   ❌ Cancel failed: $body"
    fi
else
    echo "   ⚠️  Skipped: no booking ID"
fi

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo ""
echo "========================================"
echo "  Booking Service Tests Complete"
echo "========================================"
echo ""

export LESSGO_TEST_BOOKING_ID="$bookingId"

# Update credentials file with booking ID
LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
if [ -f "$LESSGO_CREDS_FILE" ]; then
    echo "export LESSGO_TEST_BOOKING_ID=\"$bookingId\"" >> "$LESSGO_CREDS_FILE"
fi
