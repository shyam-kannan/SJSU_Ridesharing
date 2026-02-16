# ============================================================
# LessGo User Service Tests (port 3002)
# Requires: Run test-auth.ps1 first to set global variables
# ============================================================

$ErrorActionPreference = "Stop"
$BASE = "http://localhost:3002"

# Grab credentials from auth tests or use defaults
$riderToken   = if ($global:LessGoTestRiderToken)  { $global:LessGoTestRiderToken }  else { $env:LESSGO_RIDER_TOKEN }
$riderId      = if ($global:LessGoTestRiderId)     { $global:LessGoTestRiderId }     else { $env:LESSGO_RIDER_ID }
$driverToken  = if ($global:LessGoTestDriverToken) { $global:LessGoTestDriverToken } else { $env:LESSGO_DRIVER_TOKEN }
$driverId     = if ($global:LessGoTestDriverId)    { $global:LessGoTestDriverId }    else { $env:LESSGO_DRIVER_ID }

if (-not $riderToken -or -not $riderId) {
    Write-Host "`u{274C} Missing test credentials. Run test-auth.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  User Service Tests ($BASE)" -ForegroundColor Cyan
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
# 2. Get current user profile (GET /users/me)
# ----------------------------------------------------------
Write-Host "`n2. Get Current User Profile (/users/me)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $riderToken" }
    $me = Invoke-RestMethod -Uri "$BASE/users/me" -Method Get -Headers $headers

    Write-Host "   `u{2705} Profile: $($me.data.name) ($($me.data.email))" -ForegroundColor Green
    Write-Host "       Role   : $($me.data.role)" -ForegroundColor Gray
    Write-Host "       Rating : $($me.data.rating)" -ForegroundColor Gray
    Write-Host "       SJSU   : $($me.data.sjsu_id_status)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Get /me failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 3. Get user by ID (GET /users/:id)
# ----------------------------------------------------------
Write-Host "`n3. Get User By ID" -ForegroundColor Yellow
try {
    $user = Invoke-RestMethod -Uri "$BASE/users/$riderId" -Method Get

    Write-Host "   `u{2705} User: $($user.data.name) ($($user.data.email))" -ForegroundColor Green
    Write-Host "       Created: $($user.data.created_at)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Get user failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 4. Get non-existent user (expect 404)
# ----------------------------------------------------------
Write-Host "`n4. Get Non-Existent User (expect 404)" -ForegroundColor Yellow
try {
    $fakeId = "00000000-0000-0000-0000-000000000000"
    $null = Invoke-RestMethod -Uri "$BASE/users/$fakeId" -Method Get
    Write-Host "   `u{274C} Should have returned 404" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Correctly returned HTTP $status" -ForegroundColor Green
}

# ----------------------------------------------------------
# 5. Update user profile (PUT /users/:id)
# ----------------------------------------------------------
Write-Host "`n5. Update User Profile" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $riderToken" }
    $updateBody = @{ name = "Updated Rider Name" } | ConvertTo-Json

    $updated = Invoke-RestMethod -Uri "$BASE/users/$riderId" `
        -Method Put -Body $updateBody -ContentType "application/json" -Headers $headers

    Write-Host "   `u{2705} Updated name: $($updated.data.name)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Update failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 6. Update another user's profile (expect 403)
# ----------------------------------------------------------
Write-Host "`n6. Update Another User's Profile (expect 403)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $riderToken" }
    $updateBody = @{ name = "Hacker" } | ConvertTo-Json
    $fakeId = "00000000-0000-0000-0000-000000000001"

    $null = Invoke-RestMethod -Uri "$BASE/users/$fakeId" `
        -Method Put -Body $updateBody -ContentType "application/json" -Headers $headers
    Write-Host "   `u{274C} Should have returned 403" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Correctly rejected (HTTP $status)" -ForegroundColor Green
}

# ----------------------------------------------------------
# 7. Setup driver profile (PUT /users/:id/driver-setup)
# ----------------------------------------------------------
Write-Host "`n7. Setup Driver Profile" -ForegroundColor Yellow
if ($driverToken -and $driverId) {
    try {
        $headers = @{ Authorization = "Bearer $driverToken" }
        $driverBody = @{
            vehicle_info    = "2023 Tesla Model 3 - White - License ABC1234"
            seats_available = 4
        } | ConvertTo-Json

        $driver = Invoke-RestMethod -Uri "$BASE/users/$driverId/driver-setup" `
            -Method Put -Body $driverBody -ContentType "application/json" -Headers $headers

        Write-Host "   `u{2705} Driver setup: $($driver.data.vehicle_info)" -ForegroundColor Green
        Write-Host "       Seats: $($driver.data.seats_available)" -ForegroundColor Gray
        Write-Host "       Role : $($driver.data.role)" -ForegroundColor Gray
    } catch {
        Write-Host "   `u{274C} Driver setup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   `u{26A0}`u{FE0F} Skipped: no driver credentials" -ForegroundColor DarkYellow
}

# ----------------------------------------------------------
# 8. Get user ratings (GET /users/:id/ratings)
# ----------------------------------------------------------
Write-Host "`n8. Get User Ratings" -ForegroundColor Yellow
try {
    $ratings = Invoke-RestMethod -Uri "$BASE/users/$riderId/ratings" -Method Get

    Write-Host "   `u{2705} Total ratings : $($ratings.data.total_ratings)" -ForegroundColor Green
    Write-Host "       Average: $($ratings.data.average_rating)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Get ratings failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 9. Get user stats (GET /users/:id/stats)
# ----------------------------------------------------------
Write-Host "`n9. Get User Statistics" -ForegroundColor Yellow
try {
    $stats = Invoke-RestMethod -Uri "$BASE/users/$riderId/stats" -Method Get

    Write-Host "   `u{2705} Stats retrieved" -ForegroundColor Green
    Write-Host "       Total ratings    : $($stats.data.total_ratings)" -ForegroundColor Gray
    Write-Host "       Average rating   : $($stats.data.average_rating)" -ForegroundColor Gray
    Write-Host "       Bookings as rider: $($stats.data.total_bookings_as_rider)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Get stats failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  User Service Tests Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
