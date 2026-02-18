#!/bin/bash
# ============================================================
# LessGo Payment Service Tests (port 3005)
# Requires: test-auth.sh and test-trip.sh run first
# Creates its own fresh booking to avoid 409 conflicts
# Note: Stripe test keys must be configured in .env
# ============================================================

set -e
BASE="http://localhost:3005"
BOOKING_BASE="http://localhost:3004"

# Load credentials from temp file if running standalone
if [ -z "$LESSGO_TEST_RIDER_TOKEN" ]; then
    LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
    if [ -f "$LESSGO_CREDS_FILE" ]; then
        source "$LESSGO_CREDS_FILE"
    fi
fi

riderToken="${LESSGO_TEST_RIDER_TOKEN:-$LESSGO_RIDER_TOKEN}"
tripId="${LESSGO_TEST_TRIP_ID:-$LESSGO_TRIP_ID}"

echo ""
echo "========================================"
echo "  Payment Service Tests ($BASE)"
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
# 1b. Create a fresh booking for payment tests
# ----------------------------------------------------------
echo ""
echo "1b. Create Fresh Booking (for payment tests)"
paymentTestBookingId=""

if [ -n "$riderToken" ] && [ -n "$tripId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$BOOKING_BASE/bookings" \
        -H "Authorization: Bearer $riderToken" \
        -H "Content-Type: application/json" \
        -d "{\"trip_id\":\"$tripId\",\"seats_booked\":1}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        paymentTestBookingId=$(echo "$body" | jq -r '.data.booking.booking_id')
        echo "   ✅ Fresh booking: $paymentTestBookingId"
    else
        echo "   ❌ Create booking failed: $body"
    fi
else
    echo "   ⚠️  No rider token or trip ID - payment tests will be limited"
fi

# ----------------------------------------------------------
# 2. Create payment intent
# ----------------------------------------------------------
echo ""
echo "2. Create Payment Intent"
paymentId=""

if [ -n "$paymentTestBookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/payments/create-intent" \
        -H "Content-Type: application/json" \
        -d "{\"booking_id\":\"$paymentTestBookingId\",\"amount\":12.50}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        paymentId=$(echo "$body" | jq -r '.data.payment_id')
        stripeIntent=$(echo "$body" | jq -r '.data.stripe_payment_intent_id')
        amount=$(echo "$body" | jq -r '.data.amount')
        status=$(echo "$body" | jq -r '.data.status')

        echo "   ✅ Payment intent created: $paymentId"
        echo "       Stripe Intent : $stripeIntent"
        echo "       Amount        : \$$amount"
        echo "       Status        : $status"
    else
        echo "   ❌ Create intent failed: $body"
        echo "       Note: Check STRIPE_SECRET_KEY in .env"
    fi
else
    echo "   ⚠️  Skipped: no booking ID available"
fi

# ----------------------------------------------------------
# 3. Duplicate payment (expect error)
# ----------------------------------------------------------
echo ""
echo "3. Duplicate Payment Intent (expect error)"
if [ -n "$paymentId" ] && [ -n "$paymentTestBookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE/payments/create-intent" \
        -H "Content-Type: application/json" \
        -d "{\"booking_id\":\"$paymentTestBookingId\",\"amount\":12.50}")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "409" ] || [ "$http_code" = "400" ]; then
        echo "   ✅ Duplicate correctly rejected (HTTP $http_code)"
    else
        echo "   ❌ Should have been rejected"
    fi
else
    echo "   ⚠️  Skipped: no payment created"
fi

# ----------------------------------------------------------
# 4. Capture payment (skipped in test mode)
# ----------------------------------------------------------
echo ""
echo "4. Capture Payment"
if [ -n "$paymentId" ]; then
    echo "   ⚠️  Skipped: requires client-side confirmation (iOS app) before capture"
    echo "       In production, the iOS app confirms the PaymentIntent, then the server captures it"
else
    echo "   ⚠️  Skipped: no payment ID"
fi

# ----------------------------------------------------------
# 5. Get payment by booking ID
# ----------------------------------------------------------
echo ""
echo "5. Get Payment By Booking ID"
if [ -n "$paymentId" ] && [ -n "$paymentTestBookingId" ]; then
    response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/payments/booking/$paymentTestBookingId")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        paymentId=$(echo "$body" | jq -r '.data.payment_id')
        amount=$(echo "$body" | jq -r '.data.amount')
        status=$(echo "$body" | jq -r '.data.status')

        echo "   ✅ Payment found for booking"
        echo "       Payment ID : $paymentId"
        echo "       Amount     : \$$amount"
        echo "       Status     : $status"
    else
        echo "   ❌ Get payment failed"
    fi
else
    echo "   ⚠️  Skipped: no payment ID"
fi

# ----------------------------------------------------------
# 6. Refund payment (skipped in test mode)
# ----------------------------------------------------------
echo ""
echo "6. Refund Payment"
if [ -n "$paymentId" ]; then
    echo "   ⚠️  Skipped: requires captured payment (client must confirm first)"
    echo "       In production: confirm -> capture -> refund"
else
    echo "   ⚠️  Skipped: no payment ID"
fi

# ----------------------------------------------------------
# 7. Get non-existent payment (expect 404)
# ----------------------------------------------------------
echo ""
echo "7. Get Non-Existent Payment (expect 404)"
fakeId=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE/payments/booking/$fakeId")
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" = "404" ]; then
    echo "   ✅ Correctly returned HTTP $http_code"
else
    echo "   ❌ Should have returned 404"
fi

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo ""
echo "========================================"
echo "  Payment Service Tests Complete"
echo "========================================"
echo ""
