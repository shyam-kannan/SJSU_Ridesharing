# ============================================================
# LessGo Booking Service Tests (port 3004)
# Requires: test-auth.ps1 and test-trip.ps1 run first
# Also requires: Cost Calculation Service (port 3009) running
# ============================================================

$ErrorActionPreference = "Stop"
$BASE = "http://localhost:3004"

$riderToken  = if ($global:LessGoTestRiderToken)  { $global:LessGoTestRiderToken }  else { $env:LESSGO_RIDER_TOKEN }
$riderId     = if ($global:LessGoTestRiderId)     { $global:LessGoTestRiderId }     else { $env:LESSGO_RIDER_ID }
$driverToken = if ($global:LessGoTestDriverToken) { $global:LessGoTestDriverToken } else { $env:LESSGO_DRIVER_TOKEN }
$driverId    = if ($global:LessGoTestDriverId)    { $global:LessGoTestDriverId }    else { $env:LESSGO_DRIVER_ID }
$tripId      = if ($global:LessGoTestTripId)      { $global:LessGoTestTripId }      else { $env:LESSGO_TRIP_ID }

if (-not $riderToken -or -not $tripId) {
    Write-Host "`u{274C} Missing test credentials or trip ID. Run test-auth.ps1 and test-trip.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Booking Service Tests ($BASE)" -ForegroundColor Cyan
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
# 2. Create booking
# ----------------------------------------------------------
Write-Host "`n2. Create Booking (Rider books trip)" -ForegroundColor Yellow
$bookingId = $null
try {
    $headers = @{ Authorization = "Bearer $riderToken" }
    $bookingBody = @{
        trip_id      = $tripId
        seats_booked = 1
    } | ConvertTo-Json

    $booking = Invoke-RestMethod -Uri "$BASE/bookings" `
        -Method Post -Body $bookingBody -ContentType "application/json" -Headers $headers

    $bookingId = $booking.data.booking.booking_id
    Write-Host "   `u{2705} Booking created: $bookingId" -ForegroundColor Green
    Write-Host "       Status    : $($booking.data.booking.status)" -ForegroundColor Gray
    Write-Host "       Seats     : $($booking.data.booking.seats_booked)" -ForegroundColor Gray

    if ($booking.data.quote) {
        Write-Host "       Max Price : `$$($booking.data.quote.max_price)" -ForegroundColor Gray
    }
} catch {
    Write-Host "   `u{274C} Create booking failed: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "       Response: $errBody" -ForegroundColor DarkRed
    } catch {}
}

# ----------------------------------------------------------
# 3. Driver tries to book own trip (expect error)
# ----------------------------------------------------------
Write-Host "`n3. Driver Books Own Trip (expect error)" -ForegroundColor Yellow
if ($driverToken) {
    try {
        $headers = @{ Authorization = "Bearer $driverToken" }
        $bookBody = @{
            trip_id      = $tripId
            seats_booked = 1
        } | ConvertTo-Json

        $null = Invoke-RestMethod -Uri "$BASE/bookings" `
            -Method Post -Body $bookBody -ContentType "application/json" -Headers $headers
        Write-Host "   `u{274C} Should have been rejected" -ForegroundColor Red
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        Write-Host "   `u{2705} Driver correctly rejected (HTTP $status)" -ForegroundColor Green
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no driver token" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 4. Get booking details
# ----------------------------------------------------------
Write-Host "`n4. Get Booking Details" -ForegroundColor Yellow
if ($bookingId) {
    try {
        $detail = Invoke-RestMethod -Uri "$BASE/bookings/$bookingId" -Method Get

        Write-Host "   `u{2705} Booking details retrieved" -ForegroundColor Green
        Write-Host "       Status      : $($detail.data.status)" -ForegroundColor Gray
        Write-Host "       Trip        : $($detail.data.trip.origin) -> $($detail.data.trip.destination)" -ForegroundColor Gray
        Write-Host "       Rider       : $($detail.data.rider.name)" -ForegroundColor Gray

        if ($detail.data.quote) {
            Write-Host "       Quote       : `$$($detail.data.quote.max_price)" -ForegroundColor Gray
        }
        if ($detail.data.payment) {
            Write-Host "       Payment     : $($detail.data.payment.status) (`$$($detail.data.payment.amount))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   `u{274C} Get booking failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no booking ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 5. List rider's bookings
# ----------------------------------------------------------
Write-Host "`n5. List Rider's Bookings" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $riderToken" }
    $myBookings = Invoke-RestMethod -Uri "$BASE/bookings" -Method Get -Headers $headers

    Write-Host "   `u{2705} Rider has $($myBookings.data.total) booking(s)" -ForegroundColor Green

    if ($myBookings.data.bookings) {
        foreach ($b in $myBookings.data.bookings) {
            Write-Host "       - $($b.booking_id.Substring(0,8))... | $($b.status) | $($b.trip.destination)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   `u{274C} List bookings failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 6. List driver's bookings
# ----------------------------------------------------------
Write-Host "`n6. List Driver's Bookings (as_driver=true)" -ForegroundColor Yellow
if ($driverToken) {
    try {
        $headers = @{ Authorization = "Bearer $driverToken" }
        $driverBookings = Invoke-RestMethod -Uri "$BASE/bookings?as_driver=true" `
            -Method Get -Headers $headers

        Write-Host "   `u{2705} Driver sees $($driverBookings.data.total) booking(s)" -ForegroundColor Green
    } catch {
        Write-Host "   `u{274C} List driver bookings failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no driver token" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 7. Confirm booking (triggers payment)
# ----------------------------------------------------------
Write-Host "`n7. Confirm Booking (creates payment)" -ForegroundColor Yellow
if ($bookingId) {
    try {
        $headers = @{ Authorization = "Bearer $riderToken" }
        $confirmed = Invoke-RestMethod -Uri "$BASE/bookings/$bookingId/confirm" `
            -Method Put -Headers $headers

        Write-Host "   `u{2705} Booking confirmed: $($confirmed.data.status)" -ForegroundColor Green

        if ($confirmed.data.payment) {
            Write-Host "       Payment ID    : $($confirmed.data.payment.payment_id)" -ForegroundColor Gray
            Write-Host "       Payment Status: $($confirmed.data.payment.status)" -ForegroundColor Gray
            Write-Host "       Amount        : `$$($confirmed.data.payment.amount)" -ForegroundColor Gray
            $global:LessGoTestPaymentId = $confirmed.data.payment.payment_id
        }
    } catch {
        Write-Host "   `u{274C} Confirm failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Note: Payment Service (3005) and Cost Service (3009) must be running" -ForegroundColor DarkYellow
        try {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
            Write-Host "       Response: $errBody" -ForegroundColor DarkRed
        } catch {}
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no booking ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 8. Cancel booking (with refund)
# ----------------------------------------------------------
Write-Host "`n8. Cancel Booking" -ForegroundColor Yellow
if ($bookingId) {
    try {
        $headers = @{ Authorization = "Bearer $riderToken" }
        $cancelled = Invoke-RestMethod -Uri "$BASE/bookings/$bookingId/cancel" `
            -Method Put -Headers $headers

        Write-Host "   `u{2705} Booking cancelled: $($cancelled.data.status)" -ForegroundColor Green
    } catch {
        Write-Host "   `u{274C} Cancel failed: $($_.Exception.Message)" -ForegroundColor Red
        try {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
            Write-Host "       Response: $errBody" -ForegroundColor DarkRed
        } catch {}
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no booking ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Booking Service Tests Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$global:LessGoTestBookingId = $bookingId
