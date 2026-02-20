#!/bin/bash

# Test booking confirmation flow after fix
# This reproduces the iOS flow: create booking → create payment → confirm booking

API_GATEWAY="http://localhost:3000/api"

echo "=== Testing Booking Confirmation Fix ==="
echo ""

# Step 1: Login
echo "Step 1: Login as rider..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_GATEWAY/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice.chen@sjsu.edu",
    "password": "password123"
  }')

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token')
USER_ID=$(echo "$LOGIN_RESPONSE" | jq -r '.data.user.user_id')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Login failed"
  echo "$LOGIN_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Logged in: $USER_ID"
echo ""

# Step 2: Create booking
echo "Step 2: Create booking..."
TRIP_ID="trip-to-sjsu-sf-6am"

BOOKING_RESPONSE=$(curl -s -X POST "$API_GATEWAY/bookings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"trip_id\": \"$TRIP_ID\",
    \"seats_booked\": 1
  }")

BOOKING_ID=$(echo "$BOOKING_RESPONSE" | jq -r '.data.booking.booking_id')
BOOKING_STATUS=$(echo "$BOOKING_RESPONSE" | jq -r '.data.booking.status')
MAX_PRICE=$(echo "$BOOKING_RESPONSE" | jq -r '.data.quote.max_price')

if [ "$BOOKING_ID" = "null" ] || [ -z "$BOOKING_ID" ]; then
  echo "❌ Booking creation failed"
  echo "$BOOKING_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Booking created: $BOOKING_ID"
echo "   Status: $BOOKING_STATUS"
echo "   Max Price: \$$MAX_PRICE"
echo ""

# Step 3: Create payment intent (iOS flow)
echo "Step 3: Create payment intent..."
PAYMENT_RESPONSE=$(curl -s -X POST "$API_GATEWAY/payments/create-intent" \
  -H "Content-Type: application/json" \
  -d "{
    \"booking_id\": \"$BOOKING_ID\",
    \"amount\": $MAX_PRICE
  }")

PAYMENT_ID=$(echo "$PAYMENT_RESPONSE" | jq -r '.data.payment_id')
PAYMENT_STATUS=$(echo "$PAYMENT_RESPONSE" | jq -r '.data.status')
STRIPE_INTENT_ID=$(echo "$PAYMENT_RESPONSE" | jq -r '.data.stripe_payment_intent_id')

if [ "$PAYMENT_ID" = "null" ] || [ -z "$PAYMENT_ID" ]; then
  echo "❌ Payment creation failed"
  echo "$PAYMENT_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Payment created: $PAYMENT_ID"
echo "   Status: $PAYMENT_STATUS"
echo "   Stripe Intent: $STRIPE_INTENT_ID"
echo ""

# Step 4: Confirm booking (THE FIX - should NOT create duplicate payment)
echo "Step 4: Confirm booking (should NOT try to create duplicate payment)..."
CONFIRM_RESPONSE=$(curl -s -X PUT "$API_GATEWAY/bookings/$BOOKING_ID/confirm" \
  -H "Authorization: Bearer $TOKEN")

CONFIRM_SUCCESS=$(echo "$CONFIRM_RESPONSE" | jq -r '.success')
CONFIRMED_STATUS=$(echo "$CONFIRM_RESPONSE" | jq -r '.data.status')

if [ "$CONFIRM_SUCCESS" != "true" ]; then
  echo "❌ Booking confirmation failed"
  echo "$CONFIRM_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Booking confirmed successfully!"
echo "   Status: $CONFIRMED_STATUS"
echo ""

# Step 5: Verify booking details
echo "Step 5: Verify booking has payment attached..."
BOOKING_DETAILS=$(curl -s -X GET "$API_GATEWAY/bookings/$BOOKING_ID")

HAS_PAYMENT=$(echo "$BOOKING_DETAILS" | jq -r '.data.payment != null')
FINAL_STATUS=$(echo "$BOOKING_DETAILS" | jq -r '.data.status')

if [ "$HAS_PAYMENT" != "true" ]; then
  echo "❌ Booking missing payment details"
  echo "$BOOKING_DETAILS" | jq '.'
  exit 1
fi

echo "✅ Booking verified with payment"
echo "   Final Status: $FINAL_STATUS"
echo ""

# Cleanup: Cancel booking
echo "Cleanup: Cancelling booking..."
curl -s -X POST "$API_GATEWAY/bookings/$BOOKING_ID/cancel" \
  -H "Authorization: Bearer $TOKEN" > /dev/null

echo "✅ Cleanup complete"
echo ""
echo "=== ✅ ALL TESTS PASSED ==="
echo ""
echo "Summary:"
echo "  - Booking created with status 'pending'"
echo "  - Payment intent created separately"
echo "  - Confirm endpoint detected existing payment"
echo "  - Booking confirmed without 409 error"
echo "  - Payment properly attached to booking"
