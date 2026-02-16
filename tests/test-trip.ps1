# ============================================================
# LessGo Trip Service Tests (port 3003)
# Requires: Run test-auth.ps1 first to set global variables
# ============================================================

$ErrorActionPreference = "Stop"
$BASE = "http://localhost:3003"

$driverToken = if ($global:LessGoTestDriverToken) { $global:LessGoTestDriverToken } else { $env:LESSGO_DRIVER_TOKEN }
$driverId    = if ($global:LessGoTestDriverId)    { $global:LessGoTestDriverId }    else { $env:LESSGO_DRIVER_ID }
$riderToken  = if ($global:LessGoTestRiderToken)  { $global:LessGoTestRiderToken }  else { $env:LESSGO_RIDER_TOKEN }

if (-not $driverToken -or -not $driverId) {
    Write-Host "`u{274C} Missing test credentials. Run test-auth.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Trip Service Tests ($BASE)" -ForegroundColor Cyan
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
# 2. Create trip (SJSU to San Francisco)
# ----------------------------------------------------------
Write-Host "`n2. Create Trip (SJSU -> San Francisco)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $driverToken" }
    $departureTime = (Get-Date).AddDays(2).ToString("yyyy-MM-ddTHH:mm:ssZ")

    $tripBody = @{
        origin           = "San Jose State University, 1 Washington Sq, San Jose, CA 95192"
        destination      = "San Francisco Caltrain Station, 700 4th St, San Francisco, CA 94107"
        departure_time   = $departureTime
        seats_available  = 3
        recurrence       = "weekdays"
    } | ConvertTo-Json

    $trip1 = Invoke-RestMethod -Uri "$BASE/trips" `
        -Method Post -Body $tripBody -ContentType "application/json" -Headers $headers

    $tripId1 = $trip1.data.trip_id
    Write-Host "   `u{2705} Trip created: $tripId1" -ForegroundColor Green
    Write-Host "       Origin     : $($trip1.data.origin)" -ForegroundColor Gray
    Write-Host "       Destination: $($trip1.data.destination)" -ForegroundColor Gray
    Write-Host "       Departure  : $($trip1.data.departure_time)" -ForegroundColor Gray
    Write-Host "       Seats      : $($trip1.data.seats_available)" -ForegroundColor Gray
    Write-Host "       Status     : $($trip1.data.status)" -ForegroundColor Gray

    if ($trip1.data.origin_point) {
        Write-Host "       Origin GPS : $($trip1.data.origin_point.lat), $($trip1.data.origin_point.lng)" -ForegroundColor Gray
    }
} catch {
    Write-Host "   `u{274C} Create trip failed: $($_.Exception.Message)" -ForegroundColor Red
    # Try to read error body
    try {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "       Response: $errBody" -ForegroundColor DarkRed
    } catch {}
}

# ----------------------------------------------------------
# 3. Create second trip (SJSU to Palo Alto)
# ----------------------------------------------------------
Write-Host "`n3. Create Second Trip (SJSU -> Palo Alto)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $driverToken" }
    $departureTime2 = (Get-Date).AddDays(3).ToString("yyyy-MM-ddTHH:mm:ssZ")

    $tripBody2 = @{
        origin           = "San Jose State University, San Jose, CA"
        destination      = "Stanford University, 450 Serra Mall, Stanford, CA 94305"
        departure_time   = $departureTime2
        seats_available  = 2
    } | ConvertTo-Json

    $trip2 = Invoke-RestMethod -Uri "$BASE/trips" `
        -Method Post -Body $tripBody2 -ContentType "application/json" -Headers $headers

    $tripId2 = $trip2.data.trip_id
    Write-Host "   `u{2705} Trip created: $tripId2" -ForegroundColor Green
    Write-Host "       Destination: $($trip2.data.destination)" -ForegroundColor Gray
    Write-Host "       Seats      : $($trip2.data.seats_available)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Create trip 2 failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 4. Rider tries to create trip (expect 403)
# ----------------------------------------------------------
Write-Host "`n4. Rider Creates Trip (expect 403)" -ForegroundColor Yellow
if ($riderToken) {
    try {
        $headers = @{ Authorization = "Bearer $riderToken" }
        $tripBody = @{
            origin          = "SJSU"
            destination     = "Downtown"
            departure_time  = (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
            seats_available = 2
        } | ConvertTo-Json

        $null = Invoke-RestMethod -Uri "$BASE/trips" `
            -Method Post -Body $tripBody -ContentType "application/json" -Headers $headers
        Write-Host "   `u{274C} Should have returned 403" -ForegroundColor Red
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        Write-Host "   `u{2705} Rider correctly rejected (HTTP $status)" -ForegroundColor Green
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no rider token" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 5. Get trip by ID
# ----------------------------------------------------------
Write-Host "`n5. Get Trip By ID" -ForegroundColor Yellow
if ($tripId1) {
    try {
        $tripDetail = Invoke-RestMethod -Uri "$BASE/trips/$tripId1" -Method Get

        Write-Host "   `u{2705} Trip: $($tripDetail.data.origin) -> $($tripDetail.data.destination)" -ForegroundColor Green
        Write-Host "       Driver: $($tripDetail.data.driver.name)" -ForegroundColor Gray
        Write-Host "       Status: $($tripDetail.data.status)" -ForegroundColor Gray
    } catch {
        Write-Host "   `u{274C} Get trip failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no trip ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 6. Search trips near SJSU
# ----------------------------------------------------------
Write-Host "`n6. Search Trips Near SJSU (geospatial)" -ForegroundColor Yellow
try {
    # SJSU coordinates: 37.3352, -121.8811
    $searchParams = "origin_lat=37.3352&origin_lng=-121.8811&radius_meters=10000&min_seats=1"
    $search = Invoke-RestMethod -Uri "$BASE/trips/search?$searchParams" -Method Get

    $count = $search.data.total
    Write-Host "   `u{2705} Found $count trip(s) within 10km of SJSU" -ForegroundColor Green

    if ($search.data.trips -and $search.data.trips.Count -gt 0) {
        foreach ($t in $search.data.trips) {
            Write-Host "       - $($t.origin) -> $($t.destination) | seats: $($t.seats_available)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   `u{274C} Search failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 7. List all trips
# ----------------------------------------------------------
Write-Host "`n7. List All Trips" -ForegroundColor Yellow
try {
    $list = Invoke-RestMethod -Uri "$BASE/trips" -Method Get

    Write-Host "   `u{2705} Total trips: $($list.data.total)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} List trips failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 8. List driver's trips
# ----------------------------------------------------------
Write-Host "`n8. List Driver's Trips" -ForegroundColor Yellow
try {
    $driverTrips = Invoke-RestMethod -Uri "$BASE/trips?driver_id=$driverId" -Method Get

    Write-Host "   `u{2705} Driver has $($driverTrips.data.total) trip(s)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} List driver trips failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 9. Update trip
# ----------------------------------------------------------
Write-Host "`n9. Update Trip (change seats)" -ForegroundColor Yellow
if ($tripId1) {
    try {
        $headers = @{ Authorization = "Bearer $driverToken" }
        $updateBody = @{ seats_available = 4 } | ConvertTo-Json

        $updated = Invoke-RestMethod -Uri "$BASE/trips/$tripId1" `
            -Method Put -Body $updateBody -ContentType "application/json" -Headers $headers

        Write-Host "   `u{2705} Updated seats to: $($updated.data.seats_available)" -ForegroundColor Green
    } catch {
        Write-Host "   `u{274C} Update trip failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no trip ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 10. Cancel second trip
# ----------------------------------------------------------
Write-Host "`n10. Cancel Trip" -ForegroundColor Yellow
if ($tripId2) {
    try {
        $headers = @{ Authorization = "Bearer $driverToken" }
        $cancelled = Invoke-RestMethod -Uri "$BASE/trips/$tripId2" `
            -Method Delete -Headers $headers

        Write-Host "   `u{2705} Trip cancelled. Status: $($cancelled.data.status)" -ForegroundColor Green
    } catch {
        Write-Host "   `u{274C} Cancel trip failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no trip ID" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Trip Service Tests Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Export trip ID for downstream tests
$global:LessGoTestTripId = $tripId1
