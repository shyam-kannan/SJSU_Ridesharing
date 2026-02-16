# ============================================================
# LessGo Payment Service Tests (port 3005)
# Requires: test-auth.ps1 and test-trip.ps1 run first
# Creates its own fresh booking to avoid 409 conflicts
# Note: Stripe test keys must be configured in .env
# ============================================================

$ErrorActionPreference = "Stop"
$BASE = "http://localhost:3005"
$BOOKING_BASE = "http://localhost:3004"

$riderToken = if ($global:LessGoTestRiderToken) { $global:LessGoTestRiderToken } else { $env:LESSGO_RIDER_TOKEN }
$tripId     = if ($global:LessGoTestTripId)     { $global:LessGoTestTripId }     else { $env:LESSGO_TRIP_ID }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Payment Service Tests ($BASE)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ----------------------------------------------------------
# 1. Health check
# ----------------------------------------------------------
Write-Host "1. Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$BASE/health" -Method Get
    Write-Host "   `u{2705} Health: $($health.message)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Health check failed: $_" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------
# 1b. Create a fresh booking for payment tests
# ----------------------------------------------------------
Write-Host "`n1b. Create Fresh Booking (for payment tests)" -ForegroundColor Yellow
$paymentTestBookingId = $null
if ($riderToken -and $tripId) {
    try {
        $headers = @{ Authorization = "Bearer $riderToken" }
        $bookBody = @{
            trip_id      = $tripId
            seats_booked = 1
        } | ConvertTo-Json

        $booking = Invoke-RestMethod -Uri "$BOOKING_BASE/bookings" `
            -Method Post -Body $bookBody -ContentType "application/json" -Headers $headers

        $paymentTestBookingId = $booking.data.booking.booking_id
        Write-Host "   `u{2705} Fresh booking: $paymentTestBookingId" -ForegroundColor Green
    } catch {
        Write-Host "   `u{274C} Create booking failed: $($_.Exception.Message)" -ForegroundColor Red
        try {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            Write-Host "       $($reader.ReadToEnd())" -ForegroundColor DarkRed
        } catch {}
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} No rider token or trip ID - payment tests will be limited" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 2. Create payment intent
# ----------------------------------------------------------
Write-Host "`n2. Create Payment Intent" -ForegroundColor Yellow
$paymentId = $null
if ($paymentTestBookingId) {
    try {
        $intentBody = @{
            booking_id = $paymentTestBookingId
            amount     = 12.50
        } | ConvertTo-Json

        $intent = Invoke-RestMethod -Uri "$BASE/payments/create-intent" `
            -Method Post -Body $intentBody -ContentType "application/json"

        $paymentId = $intent.data.payment_id
        Write-Host "   `u{2705} Payment intent created: $paymentId" -ForegroundColor Green
        Write-Host "       Stripe Intent : $($intent.data.stripe_payment_intent_id)" -ForegroundColor Gray
        Write-Host "       Amount        : `$$($intent.data.amount)" -ForegroundColor Gray
        Write-Host "       Status        : $($intent.data.status)" -ForegroundColor Gray
    } catch {
        Write-Host "   `u{274C} Create intent failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Note: Check STRIPE_SECRET_KEY in .env" -ForegroundColor DarkYellow
        try {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
            Write-Host "       Response: $errBody" -ForegroundColor DarkRed
        } catch {}
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no booking ID available" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 3. Duplicate payment (expect error)
# ----------------------------------------------------------
Write-Host "`n3. Duplicate Payment Intent (expect error)" -ForegroundColor Yellow
if ($paymentId -and $paymentTestBookingId) {
    try {
        $dupBody = @{
            booking_id = $paymentTestBookingId
            amount     = 12.50
        } | ConvertTo-Json

        $null = Invoke-RestMethod -Uri "$BASE/payments/create-intent" `
            -Method Post -Body $dupBody -ContentType "application/json"
        Write-Host "   `u{274C} Should have been rejected" -ForegroundColor Red
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        Write-Host "   `u{2705} Duplicate correctly rejected (HTTP $status)" -ForegroundColor Green
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no payment created" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 4. Capture payment (skipped in test mode)
# ----------------------------------------------------------
Write-Host "`n4. Capture Payment" -ForegroundColor Yellow
if ($paymentId) {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: requires client-side confirmation (iOS app) before capture" -ForegroundColor DarkYellow
    Write-Host "       In production, the iOS app confirms the PaymentIntent, then the server captures it" -ForegroundColor Gray
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no payment ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 5. Get payment by booking ID
# ----------------------------------------------------------
Write-Host "`n5. Get Payment By Booking ID" -ForegroundColor Yellow
if ($paymentId -and $paymentTestBookingId) {
    try {
        $payment = Invoke-RestMethod -Uri "$BASE/payments/booking/$paymentTestBookingId" -Method Get

        Write-Host "   `u{2705} Payment found for booking" -ForegroundColor Green
        Write-Host "       Payment ID : $($payment.data.payment_id)" -ForegroundColor Gray
        Write-Host "       Amount     : `$$($payment.data.amount)" -ForegroundColor Gray
        Write-Host "       Status     : $($payment.data.status)" -ForegroundColor Gray
    } catch {
        Write-Host "   `u{274C} Get payment failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no payment ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 6. Refund payment (skipped in test mode)
# ----------------------------------------------------------
Write-Host "`n6. Refund Payment" -ForegroundColor Yellow
if ($paymentId) {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: requires captured payment (client must confirm first)" -ForegroundColor DarkYellow
    Write-Host "       In production: confirm -> capture -> refund" -ForegroundColor Gray
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no payment ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 7. Get non-existent payment (expect 404)
# ----------------------------------------------------------
Write-Host "`n7. Get Non-Existent Payment (expect 404)" -ForegroundColor Yellow
try {
    $fakeId = [System.Guid]::NewGuid().ToString()
    $null = Invoke-RestMethod -Uri "$BASE/payments/booking/$fakeId" -Method Get
    Write-Host "   `u{274C} Should have returned 404" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Correctly returned HTTP $status" -ForegroundColor Green
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Payment Service Tests Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
