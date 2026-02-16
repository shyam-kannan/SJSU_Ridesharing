# ============================================================
# LessGo Auth Service Tests (port 3001)
# ============================================================

$ErrorActionPreference = "Stop"
$BASE = "http://localhost:3001"
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$testEmail = "testuser-$timestamp@sjsu.edu"
$testPassword = "TestPass123"
$testName = "Test User $timestamp"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Auth Service Tests ($BASE)" -ForegroundColor Cyan
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
# 2. Register new user (Rider)
# ----------------------------------------------------------
Write-Host "`n2. Register New User (Rider)" -ForegroundColor Yellow
try {
    $registerBody = @{
        name     = $testName
        email    = $testEmail
        password = $testPassword
        role     = "Rider"
    } | ConvertTo-Json

    $register = Invoke-RestMethod -Uri "$BASE/auth/register" `
        -Method Post -Body $registerBody -ContentType "application/json"

    $userId     = $register.data.user.user_id
    $accessToken  = $register.data.accessToken
    $refreshToken = $register.data.refreshToken

    Write-Host "   `u{2705} Registered: $($register.data.user.name) ($($register.data.user.email))" -ForegroundColor Green
    Write-Host "       User ID : $userId" -ForegroundColor Gray
    Write-Host "       Role    : $($register.data.user.role)" -ForegroundColor Gray
    Write-Host "       SJSU    : $($register.data.user.sjsu_id_status)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Register failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------
# 2b. Auto-verify Rider (test-only endpoint)
# ----------------------------------------------------------
Write-Host "`n2b. Auto-Verify Rider (test-only)" -ForegroundColor Yellow
try {
    $verified = Invoke-RestMethod -Uri "$BASE/auth/test/verify/$userId" -Method Post
    Write-Host "   `u{2705} Rider verified: sjsu_id_status=$($verified.data.sjsu_id_status)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Verify rider failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 3. Register duplicate (expect 409)
# ----------------------------------------------------------
Write-Host "`n3. Register Duplicate (expect error)" -ForegroundColor Yellow
try {
    $dupBody = @{
        name     = $testName
        email    = $testEmail
        password = $testPassword
        role     = "Rider"
    } | ConvertTo-Json

    $null = Invoke-RestMethod -Uri "$BASE/auth/register" `
        -Method Post -Body $dupBody -ContentType "application/json"
    Write-Host "   `u{274C} Should have returned 409" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Duplicate correctly rejected (HTTP $status)" -ForegroundColor Green
}

# ----------------------------------------------------------
# 4. Login
# ----------------------------------------------------------
Write-Host "`n4. Login" -ForegroundColor Yellow
try {
    $loginBody = @{
        email    = $testEmail
        password = $testPassword
    } | ConvertTo-Json

    $login = Invoke-RestMethod -Uri "$BASE/auth/login" `
        -Method Post -Body $loginBody -ContentType "application/json"

    $accessToken  = $login.data.accessToken
    $refreshToken = $login.data.refreshToken

    Write-Host "   `u{2705} Login successful: $($login.data.user.name)" -ForegroundColor Green
    Write-Host "       Access token : $($accessToken.Substring(0,30))..." -ForegroundColor Gray
    Write-Host "       Refresh token: $($refreshToken.Substring(0,30))..." -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------
# 5. Login with wrong password (expect 401)
# ----------------------------------------------------------
Write-Host "`n5. Login with Wrong Password (expect error)" -ForegroundColor Yellow
try {
    $badLogin = @{
        email    = $testEmail
        password = "WrongPassword999"
    } | ConvertTo-Json

    $null = Invoke-RestMethod -Uri "$BASE/auth/login" `
        -Method Post -Body $badLogin -ContentType "application/json"
    Write-Host "   `u{274C} Should have returned 401" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Wrong password correctly rejected (HTTP $status)" -ForegroundColor Green
}

# ----------------------------------------------------------
# 6. Verify token
# ----------------------------------------------------------
Write-Host "`n6. Verify Token" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $accessToken" }
    $verify = Invoke-RestMethod -Uri "$BASE/auth/verify" `
        -Method Get -Headers $headers

    Write-Host "   `u{2705} Token valid: $($verify.data.valid), user: $($verify.data.user.email)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Verify failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 7. Refresh token
# ----------------------------------------------------------
Write-Host "`n7. Refresh Token" -ForegroundColor Yellow
try {
    $refreshBody = @{ refreshToken = $refreshToken } | ConvertTo-Json

    $refresh = Invoke-RestMethod -Uri "$BASE/auth/refresh" `
        -Method Post -Body $refreshBody -ContentType "application/json"

    $newAccessToken = $refresh.data.accessToken

    Write-Host "   `u{2705} New access token: $($newAccessToken.Substring(0,30))..." -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Refresh failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 8. Get current user (/auth/me)
# ----------------------------------------------------------
Write-Host "`n8. Get Current User (/auth/me)" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $accessToken" }
    $me = Invoke-RestMethod -Uri "$BASE/auth/me" -Method Get -Headers $headers

    Write-Host "   `u{2705} Current user: $($me.data.name) ($($me.data.email))" -ForegroundColor Green
    Write-Host "       Rating: $($me.data.rating)" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Get /me failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 9. Access protected route without token (expect 401)
# ----------------------------------------------------------
Write-Host "`n9. Access Without Token (expect 401)" -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "$BASE/auth/verify" -Method Get
    Write-Host "   `u{274C} Should have returned 401" -ForegroundColor Red
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "   `u{2705} Correctly rejected without token (HTTP $status)" -ForegroundColor Green
}

# ----------------------------------------------------------
# 10. Logout
# ----------------------------------------------------------
Write-Host "`n10. Logout" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $accessToken" }
    $logout = Invoke-RestMethod -Uri "$BASE/auth/logout" `
        -Method Post -Headers $headers

    Write-Host "   `u{2705} $($logout.message)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Logout failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 11. Register Driver (for other tests)
# ----------------------------------------------------------
Write-Host "`n11. Register Driver User" -ForegroundColor Yellow
try {
    $driverBody = @{
        name     = "Driver $timestamp"
        email    = "driver-$timestamp@sjsu.edu"
        password = $testPassword
        role     = "Driver"
    } | ConvertTo-Json

    $driverReg = Invoke-RestMethod -Uri "$BASE/auth/register" `
        -Method Post -Body $driverBody -ContentType "application/json"

    $driverUserId = $driverReg.data.user.user_id
    $driverToken  = $driverReg.data.accessToken

    Write-Host "   `u{2705} Driver registered: $($driverReg.data.user.name)" -ForegroundColor Green
    Write-Host "       Driver ID: $driverUserId" -ForegroundColor Gray
} catch {
    Write-Host "   `u{274C} Driver registration failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 11b. Auto-verify Driver (test-only endpoint)
# ----------------------------------------------------------
Write-Host "`n11b. Auto-Verify Driver (test-only)" -ForegroundColor Yellow
try {
    $verified = Invoke-RestMethod -Uri "$BASE/auth/test/verify/$driverUserId" -Method Post
    Write-Host "   `u{2705} Driver verified: sjsu_id_status=$($verified.data.sjsu_id_status)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Verify driver failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# 12. Re-login both users (get tokens with verified status)
# ----------------------------------------------------------
Write-Host "`n12. Re-login Users (get verified tokens)" -ForegroundColor Yellow
try {
    $riderLoginBody = @{
        email    = $testEmail
        password = $testPassword
    } | ConvertTo-Json

    $riderLogin = Invoke-RestMethod -Uri "$BASE/auth/login" `
        -Method Post -Body $riderLoginBody -ContentType "application/json"

    $accessToken  = $riderLogin.data.accessToken
    $refreshToken = $riderLogin.data.refreshToken

    Write-Host "   `u{2705} Rider re-logged in (verified token)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Rider re-login failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $driverLoginBody = @{
        email    = "driver-$timestamp@sjsu.edu"
        password = $testPassword
    } | ConvertTo-Json

    $driverLogin = Invoke-RestMethod -Uri "$BASE/auth/login" `
        -Method Post -Body $driverLoginBody -ContentType "application/json"

    $driverToken = $driverLogin.data.accessToken

    Write-Host "   `u{2705} Driver re-logged in (verified token)" -ForegroundColor Green
} catch {
    Write-Host "   `u{274C} Driver re-login failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Auth Tests Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Rider  : $testEmail / $testPassword" -ForegroundColor Gray
Write-Host "  Driver : driver-$timestamp@sjsu.edu / $testPassword" -ForegroundColor Gray
Write-Host "  Rider Token  : $($accessToken.Substring(0,20))..." -ForegroundColor Gray
Write-Host "  Driver Token : $($driverToken.Substring(0,20))..." -ForegroundColor Gray
Write-Host ""

# Export for downstream scripts
$global:LessGoTestRiderEmail    = $testEmail
$global:LessGoTestRiderPassword = $testPassword
$global:LessGoTestRiderToken    = $accessToken
$global:LessGoTestRiderId       = $userId
$global:LessGoTestDriverEmail   = "driver-$timestamp@sjsu.edu"
$global:LessGoTestDriverToken   = $driverToken
$global:LessGoTestDriverId      = $driverUserId
$global:LessGoTestTimestamp     = $timestamp
