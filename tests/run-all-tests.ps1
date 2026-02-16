# ============================================================
# LessGo - Run All Service Tests
# ============================================================
#
# Usage:
#   .\tests\run-all-tests.ps1              # Run individual service tests
#   .\tests\run-all-tests.ps1 -Gateway     # Run E2E gateway tests only
#   .\tests\run-all-tests.ps1 -All         # Run both individual + gateway
#
# Prerequisites:
#   - PostgreSQL running with migrations applied
#   - Services running on their configured ports
#   - .env configured with valid keys
#
# Service ports:
#   Auth: 3001, User: 3002, Trip: 3003
#   Booking: 3004, Payment: 3005
#   Cost: 3009, API Gateway: 3000
# ============================================================

param(
    [switch]$Gateway,
    [switch]$All
)

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot

function Write-Banner {
    param([string]$text)
    $line = "=" * 56
    Write-Host ""
    Write-Host $line -ForegroundColor Magenta
    Write-Host "  $text" -ForegroundColor Magenta
    Write-Host $line -ForegroundColor Magenta
    Write-Host ""
}

function Test-ServiceHealth {
    param([string]$name, [string]$url)

    try {
        $null = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 3
        Write-Host "  `u{2705} $name" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  `u{274C} $name - NOT RUNNING" -ForegroundColor Red
        return $false
    }
}

# ----------------------------------------------------------
# Pre-flight: Check which services are running
# ----------------------------------------------------------
Write-Banner "Pre-flight: Checking Services"

$services = @{
    "Auth Service (3001)"         = "http://localhost:3001/health"
    "User Service (3002)"         = "http://localhost:3002/health"
    "Trip Service (3003)"         = "http://localhost:3003/health"
    "Booking Service (3004)"      = "http://localhost:3004/health"
    "Payment Service (3005)"      = "http://localhost:3005/health"
    "Cost Service (3009)"         = "http://localhost:3009/health"
    "Notification Service (3006)" = "http://localhost:3006/health"
    "API Gateway (3000)"          = "http://localhost:3000/health"
}

$running = @{}
foreach ($svc in $services.GetEnumerator()) {
    $running[$svc.Key] = Test-ServiceHealth -name $svc.Key -url $svc.Value
}

$requiredForIndividual = @(
    "Auth Service (3001)",
    "User Service (3002)",
    "Trip Service (3003)"
)

$requiredForGateway = @(
    "API Gateway (3000)",
    "Auth Service (3001)",
    "User Service (3002)",
    "Trip Service (3003)"
)

# ----------------------------------------------------------
# Run individual service tests
# ----------------------------------------------------------
if (-not $Gateway) {
    $canRunIndividual = $true
    foreach ($req in $requiredForIndividual) {
        if (-not $running[$req]) {
            $canRunIndividual = $false
        }
    }

    if (-not $canRunIndividual) {
        Write-Host "`n`u{26A0}`u{FE0F}  Cannot run individual tests - required services not running" -ForegroundColor DarkYellow
        Write-Host "  Required: Auth (3001), User (3002), Trip (3003)`n" -ForegroundColor Gray
    } else {
        # Auth tests (must run first - sets up test credentials)
        Write-Banner "Running Auth Service Tests"
        . "$scriptDir\test-auth.ps1"

        # User tests
        if ($running["User Service (3002)"]) {
            Write-Banner "Running User Service Tests"
            . "$scriptDir\test-user.ps1"
        }

        # Trip tests
        if ($running["Trip Service (3003)"]) {
            Write-Banner "Running Trip Service Tests"
            . "$scriptDir\test-trip.ps1"
        }

        # Booking tests (needs Cost Service too)
        if ($running["Booking Service (3004)"]) {
            Write-Banner "Running Booking Service Tests"
            if (-not $running["Cost Service (3009)"]) {
                Write-Host "  `u{26A0}`u{FE0F}  Cost Service (3009) not running - booking creation may fail" -ForegroundColor DarkYellow
            }
            . "$scriptDir\test-booking.ps1"
        } else {
            Write-Host "`n  Skipping Booking tests - service not running" -ForegroundColor DarkYellow
        }

        # Payment tests (needs Stripe keys)
        if ($running["Payment Service (3005)"]) {
            Write-Banner "Running Payment Service Tests"
            . "$scriptDir\test-payment.ps1"
        } else {
            Write-Host "`n  Skipping Payment tests - service not running" -ForegroundColor DarkYellow
        }
    }
}

# ----------------------------------------------------------
# Run gateway E2E tests
# ----------------------------------------------------------
if ($Gateway -or $All) {
    $canRunGateway = $true
    foreach ($req in $requiredForGateway) {
        if (-not $running[$req]) {
            $canRunGateway = $false
        }
    }

    if (-not $canRunGateway) {
        Write-Host "`n`u{26A0}`u{FE0F}  Cannot run gateway tests - required services not running" -ForegroundColor DarkYellow
        Write-Host "  Required: Gateway (3000), Auth (3001), User (3002), Trip (3003)`n" -ForegroundColor Gray
    } else {
        Write-Banner "Running API Gateway E2E Tests"
        . "$scriptDir\test-gateway.ps1"
    }
}

# ----------------------------------------------------------
# Final summary
# ----------------------------------------------------------
Write-Banner "All Tests Complete"

Write-Host "  Services tested:" -ForegroundColor Gray
if (-not $Gateway) {
    if ($running["Auth Service (3001)"])    { Write-Host "    `u{2705} Auth Service" -ForegroundColor Green }
    if ($running["User Service (3002)"])    { Write-Host "    `u{2705} User Service" -ForegroundColor Green }
    if ($running["Trip Service (3003)"])    { Write-Host "    `u{2705} Trip Service" -ForegroundColor Green }
    if ($running["Booking Service (3004)"]) { Write-Host "    `u{2705} Booking Service" -ForegroundColor Green }
    if ($running["Payment Service (3005)"]) { Write-Host "    `u{2705} Payment Service" -ForegroundColor Green }
}
if ($Gateway -or $All) {
    if ($running["API Gateway (3000)"])     { Write-Host "    `u{2705} API Gateway (E2E)" -ForegroundColor Green }
}

Write-Host ""
