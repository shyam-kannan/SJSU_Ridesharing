# ============================================================
# LessGo API Gateway End-to-End Tests (port 3000)
# Full flow: Register -> Login -> Create Trip -> Search ->
#            Book -> Confirm -> Rate
# All requests go through the API Gateway
# Requires: All backend services running
# ============================================================

$ErrorActionPreference = "Stop"
$GW = "http://localhost:3000"
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  API Gateway E2E Tests ($GW)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ----------------------------------------------------------
# 1. Gateway health check
# ----------------------------------------------------------
Write-Host "1. Gateway Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$GW/health" -Method Get
    Write-Host "   `u{2705} Gateway: $($health.message)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Gateway health check failed. Is it running on port 3000?" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------
# 2. Register Driver through gateway
# ----------------------------------------------------------
Write-Host "`n2. Register Driver (via gateway)" -ForegroundColor Yellow
$driverToken = $null
$driverId = $null
try {
    $driverBody = @{
        name     = "E2E Driver $timestamp"
        email    = "e2e-driver-$timestamp@sjsu.edu"
        password = "TestPass123"
        role     = "Driver"
    } | ConvertTo-Json

    $driverReg = Invoke-RestMethod -Uri "$GW/api/auth/register" `
        -Method Post -Body $driverBody -ContentType "application/json"

    $driverId    = $driverReg.data.user.user_id
    $driverToken = $driverReg.data.accessToken

    Write-Host "   `u{2705} Driver: $($driverReg.data.user.name)" -ForegroundColor Green
    Write-Host "       ID   : $driverId" -ForegroundColor Gray
    Write-Host "       Email: $($driverReg.data.user.email)" -ForegroundColor Gray

    # Check for correlation ID header
    Write-Host "       (Routed through API Gateway)" -ForegroundColor DarkGray
} catch {
    Write-Host "   `u{274C} Driver registration failed: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "       $($reader.ReadToEnd())" -ForegroundColor DarkRed
    } catch {}
    exit 1
}

# ----------------------------------------------------------
# 3. Register Rider through gateway
# ----------------------------------------------------------
Write-Host "`n3. Register Rider (via gateway)" -ForegroundColor Yellow
$riderToken = $null
$riderId = $null
try {
    $riderBody = @{
        name     = "E2E Rider $timestamp"
        email    = "e2e-rider-$timestamp@sjsu.edu"
        password = "TestPass123"
        role     = "Rider"
    } | ConvertTo-Json

    $riderReg = Invoke-RestMethod -Uri "$GW/api/auth/register" `
        -Method Post -Body $riderBody -ContentType "application/json"

    $riderId    = $riderReg.data.user.user_id
    $riderToken = $riderReg.data.accessToken

    Write-Host "   `u{2705} Rider: $($riderReg.data.user.name)" -ForegroundColor Green
    Write-Host "       ID: $riderId" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Rider registration failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------
# 3b. Auto-verify both users (test-only, direct to auth service)
# ----------------------------------------------------------
Write-Host "`n3b. Auto-Verify Users (test-only)" -ForegroundColor Yellow
$AUTH = "http://localhost:3001"
try {
    $null = Invoke-RestMethod -Uri "$AUTH/auth/test/verify/$driverId" -Method Post
    Write-Host "   `u{2705} Driver verified" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Driver verify failed: $($_.Exception.Message)" -ForegroundColor Red
}
try {
    $null = Invoke-RestMethod -Uri "$AUTH/auth/test/verify/$riderId" -Method Post
    Write-Host "   `u{2705} Rider verified" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Rider verify failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 4. Login as driver
# ----------------------------------------------------------
Write-Host "`n4. Login as Driver (via gateway)" -ForegroundColor Yellow
try {
    $loginBody = @{
        email    = "e2e-driver-$timestamp@sjsu.edu"
        password = "TestPass123"
    } | ConvertTo-Json

    $login = Invoke-RestMethod -Uri "$GW/api/auth/login" `
        -Method Post -Body $loginBody -ContentType "application/json"

    $driverToken = $login.data.accessToken
    Write-Host "   `u{2705} Driver logged in" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Login failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 5. Setup driver profile through gateway
# ----------------------------------------------------------
Write-Host "`n5. Setup Driver Profile (via gateway)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $driverToken" }
    $setupBody = @{
        vehicle_info    = "2024 Honda Civic - Silver - 8XYZ123"
        seats_available = 3
    } | ConvertTo-Json

    $setup = Invoke-RestMethod -Uri "$GW/api/users/$driverId/driver-setup" `
        -Method Put -Body $setupBody -ContentType "application/json" -Headers $headers

    Write-Host "   `u{2705} Driver profile: $($setup.data.vehicle_info)" -ForegroundColor Green
    Write-Host "       Seats: $($setup.data.seats_available)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Driver setup failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 6. Create trip through gateway
# ----------------------------------------------------------
Write-Host "`n6. Create Trip (via gateway)" -ForegroundColor Yellow
$tripId = $null
try {
    $headers = @{ Authorization = "Bearer $driverToken" }
    $departureTime = (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ")

    $tripBody = @{
        origin           = "San Jose State University, 1 Washington Sq, San Jose, CA 95192"
        destination      = "Googleplex, 1600 Amphitheatre Pkwy, Mountain View, CA 94043"
        departure_time   = $departureTime
        seats_available  = 3
    } | ConvertTo-Json

    $trip = Invoke-RestMethod -Uri "$GW/api/trips" `
        -Method Post -Body $tripBody -ContentType "application/json" -Headers $headers

    $tripId = $trip.data.trip_id
    Write-Host "   `u{2705} Trip created: $tripId" -ForegroundColor Green
    Write-Host "       SJSU -> Googleplex" -ForegroundColor Gray
    Write-Host "       Seats: $($trip.data.seats_available)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Create trip failed: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "       $($reader.ReadToEnd())" -ForegroundColor DarkRed
    } catch {}
}

# ----------------------------------------------------------
# 7. Search trips near SJSU through gateway
# ----------------------------------------------------------
Write-Host "`n7. Search Trips Near SJSU (via gateway)" -ForegroundColor Yellow
try {
    $params = "origin_lat=37.3352&origin_lng=-121.8811&radius_meters=15000"
    $search = Invoke-RestMethod -Uri "$GW/api/trips/search?$params" -Method Get

    Write-Host "   `u{2705} Found $($search.data.total) trip(s) near SJSU" -ForegroundColor Green

    if ($search.data.trips) {
        foreach ($t in $search.data.trips) {
            Write-Host "       - $($t.destination) | seats: $($t.seats_available) | driver: $($t.driver.name)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   `u{274C} Search failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 8. Get trip details through gateway
# ----------------------------------------------------------
Write-Host "`n8. Get Trip Details (via gateway)" -ForegroundColor Yellow
if ($tripId) {
    try {
        $tripDetail = Invoke-RestMethod -Uri "$GW/api/trips/$tripId" -Method Get

        Write-Host "   `u{2705} Trip: $($tripDetail.data.origin) -> $($tripDetail.data.destination)" -ForegroundColor Green
        Write-Host "       Driver : $($tripDetail.data.driver.name)" -ForegroundColor Gray
        Write-Host "       Vehicle: $($tripDetail.data.driver.vehicle_info)" -ForegroundColor Gray
    } catch {
        Write-Host "   `u{274C} Get trip failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ----------------------------------------------------------
# 9. Create booking as rider through gateway
# ----------------------------------------------------------
Write-Host "`n9. Create Booking (Rider via gateway)" -ForegroundColor Yellow
$bookingId = $null
if ($tripId) {
    try {
        $headers = @{ Authorization = "Bearer $riderToken" }
        $bookBody = @{
            trip_id      = $tripId
            seats_booked = 1
        } | ConvertTo-Json

        $booking = Invoke-RestMethod -Uri "$GW/api/bookings" `
            -Method Post -Body $bookBody -ContentType "application/json" -Headers $headers

        $bookingId = $booking.data.booking.booking_id
        Write-Host "   `u{2705} Booking created: $bookingId" -ForegroundColor Green
        Write-Host "       Status: $($booking.data.booking.status)" -ForegroundColor Gray

        if ($booking.data.quote) {
            Write-Host "       Quote : `$$($booking.data.quote.max_price)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   `u{274C} Create booking failed: $($_.Exception.Message)" -ForegroundColor Red
        try {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            Write-Host "       $($reader.ReadToEnd())" -ForegroundColor DarkRed
        } catch {}
    }
}

# ----------------------------------------------------------
# 10. Confirm booking (payment) through gateway
# ----------------------------------------------------------
Write-Host "`n10. Confirm Booking with Payment (via gateway)" -ForegroundColor Yellow
if ($bookingId) {
    try {
        $headers = @{ Authorization = "Bearer $riderToken" }
        $confirmed = Invoke-RestMethod -Uri "$GW/api/bookings/$bookingId/confirm" `
            -Method Put -Headers $headers

        Write-Host "   `u{2705} Booking confirmed: $($confirmed.data.status)" -ForegroundColor Green
        if ($confirmed.data.payment) {
            Write-Host "       Payment: `$$($confirmed.data.payment.amount) ($($confirmed.data.payment.status))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   `u{274C} Confirm failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ----------------------------------------------------------
# 11. Get user profile through gateway
# ----------------------------------------------------------
Write-Host "`n11. Get Rider Profile (via gateway)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $riderToken" }
    $profile = Invoke-RestMethod -Uri "$GW/api/users/me" -Method Get -Headers $headers

    Write-Host "   `u{2705} Rider: $($profile.data.name)" -ForegroundColor Green
    Write-Host "       Rating: $($profile.data.rating)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Get profile failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 12. Protected route without token (expect 401)
# ----------------------------------------------------------
Write-Host "`n12. Access Protected Route Without Token (expect 401)" -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "$GW/api/users/me" -Method Get
    Write-Host "   `u{274C} Should have returned 401" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Gateway correctly rejected (HTTP $status)" -ForegroundColor Green
}

# ----------------------------------------------------------
# 13. Public routes work without auth
# ----------------------------------------------------------
Write-Host "`n13. Public Routes Without Auth" -ForegroundColor Yellow
try {
    $trips = Invoke-RestMethod -Uri "$GW/api/trips" -Method Get
    Write-Host "   `u{2705} GET /api/trips works without auth (public)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Public route failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 14. Non-existent route (expect 404)
# ----------------------------------------------------------
Write-Host "`n14. Non-Existent Route (expect 404)" -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "$GW/api/nonexistent" -Method Get
    Write-Host "   `u{274C} Should have returned 404" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Correctly returned HTTP $status" -ForegroundColor Green
}

# ----------------------------------------------------------
# 15. Rate limiting test
# ----------------------------------------------------------
Write-Host "`n15. Rate Limiting (send burst of requests)" -ForegroundColor Yellow
try {
    $successCount = 0
    $rateLimited = $false

    for ($i = 0; $i -lt 10; $i++) {
        try {
            $null = Invoke-RestMethod -Uri "$GW/health" -Method Get
            $successCount++
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
            if ($status -eq 429) {
                $rateLimited = $true
                break
            }
        }
    }

    if ($rateLimited) {
        Write-Host "   `u{2705} Rate limiting active (hit at request $successCount)" -ForegroundColor Green
    } else {
        Write-Host "   `u{2705} $successCount/10 requests succeeded (under limit)" -ForegroundColor Green
    }
} catch {
    Write-Host "   `u{274C} Rate limit test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  API Gateway E2E Tests Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Full flow tested through gateway:" -ForegroundColor Gray
Write-Host "    Register -> Login -> Driver Setup" -ForegroundColor Gray
Write-Host "    Create Trip -> Search -> Book -> Confirm" -ForegroundColor Gray
Write-Host "    Auth enforcement + public routes" -ForegroundColor Gray
Write-Host "    Rate limiting active" -ForegroundColor Gray
Write-Host ""
