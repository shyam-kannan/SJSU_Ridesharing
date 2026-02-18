#!/bin/bash
# ============================================================
# LessGo - Run All Service Tests
# ============================================================
#
# Usage:
#   ./tests/run-all-tests.sh              # Run individual service tests
#   ./tests/run-all-tests.sh --gateway    # Run E2E gateway tests only
#   ./tests/run-all-tests.sh --all        # Run both individual + gateway
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

set +e  # Don't exit on error for this orchestrator script
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

gateway=false
all=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --gateway)
            gateway=true
            ;;
        --all)
            all=true
            ;;
    esac
done

# ANSI color codes
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

function write_banner() {
    local text="$1"
    local line="========================================================"
    echo ""
    echo -e "${MAGENTA}${line}${NC}"
    echo -e "${MAGENTA}  ${text}${NC}"
    echo -e "${MAGENTA}${line}${NC}"
    echo ""
}

function test_service_health() {
    local name="$1"
    local url="$2"

    if curl -s -f -m 3 "$url" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ ${name}${NC}"
        return 0
    else
        echo -e "  ${RED}❌ ${name} - NOT RUNNING${NC}"
        return 1
    fi
}

# ----------------------------------------------------------
# Pre-flight: Check which services are running
# ----------------------------------------------------------
write_banner "Pre-flight: Checking Services"

# Simple variables instead of associative arrays (bash 3.2 compatible)
auth_running=false
user_running=false
trip_running=false
booking_running=false
payment_running=false
cost_running=false
notification_running=false
gateway_running=false

test_service_health "Auth Service (3001)" "http://localhost:3001/health" && auth_running=true
test_service_health "User Service (3002)" "http://localhost:3002/health" && user_running=true
test_service_health "Trip Service (3003)" "http://localhost:3003/health" && trip_running=true
test_service_health "Booking Service (3004)" "http://localhost:3004/health" && booking_running=true
test_service_health "Payment Service (3005)" "http://localhost:3005/health" && payment_running=true
test_service_health "Cost Service (3009)" "http://localhost:3009/health" && cost_running=true
test_service_health "Notification Service (3006)" "http://localhost:3006/health" && notification_running=true
test_service_health "API Gateway (3000)" "http://localhost:3000/health" && gateway_running=true

# ----------------------------------------------------------
# Run individual service tests
# ----------------------------------------------------------
if [ "$gateway" = false ]; then
    canRunIndividual=true

    if [ "$auth_running" = false ] || [ "$user_running" = false ] || [ "$trip_running" = false ]; then
        canRunIndividual=false
    fi

    if [ "$canRunIndividual" = false ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Cannot run individual tests - required services not running${NC}"
        echo -e "${GRAY}  Required: Auth (3001), User (3002), Trip (3003)${NC}"
        echo ""
    else
        # Auth tests (must run first - sets up test credentials)
        write_banner "Running Auth Service Tests"
        bash "$scriptDir/test-auth.sh"

        # Load the credentials that auth test saved
        LESSGO_CREDS_FILE=$(ls -t /tmp/lessgo-test-credentials-*.sh 2>/dev/null | head -1)
        if [ -f "$LESSGO_CREDS_FILE" ]; then
            echo ""
            echo -e "${GREEN}Loading credentials from: $LESSGO_CREDS_FILE${NC}"
            source "$LESSGO_CREDS_FILE"
        else
            echo ""
            echo -e "${RED}Warning: Could not find credentials file${NC}"
        fi

        # User tests
        if [ "$user_running" = true ]; then
            write_banner "Running User Service Tests"
            bash "$scriptDir/test-user.sh"
        fi

        # Trip tests
        if [ "$trip_running" = true ]; then
            write_banner "Running Trip Service Tests"
            bash "$scriptDir/test-trip.sh"
            # Reload credentials to get trip ID
            [ -f "$LESSGO_CREDS_FILE" ] && source "$LESSGO_CREDS_FILE"
        fi

        # Booking tests (needs Cost Service too)
        if [ "$booking_running" = true ]; then
            write_banner "Running Booking Service Tests"
            if [ "$cost_running" = false ]; then
                echo -e "${YELLOW}  ⚠️  Cost Service (3009) not running - booking creation may fail${NC}"
            fi
            bash "$scriptDir/test-booking.sh"
            # Reload credentials to get booking ID
            [ -f "$LESSGO_CREDS_FILE" ] && source "$LESSGO_CREDS_FILE"
        else
            echo ""
            echo -e "${YELLOW}  Skipping Booking tests - service not running${NC}"
        fi

        # Payment tests (needs Stripe keys)
        if [ "$payment_running" = true ]; then
            write_banner "Running Payment Service Tests"
            bash "$scriptDir/test-payment.sh"
        else
            echo ""
            echo -e "${YELLOW}  Skipping Payment tests - service not running${NC}"
        fi
    fi
fi

# ----------------------------------------------------------
# Run gateway E2E tests
# ----------------------------------------------------------
if [ "$gateway" = true ] || [ "$all" = true ]; then
    canRunGateway=true

    if [ "$gateway_running" = false ] || [ "$auth_running" = false ] || \
       [ "$user_running" = false ] || [ "$trip_running" = false ]; then
        canRunGateway=false
    fi

    if [ "$canRunGateway" = false ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Cannot run gateway tests - required services not running${NC}"
        echo -e "${GRAY}  Required: Gateway (3000), Auth (3001), User (3002), Trip (3003)${NC}"
        echo ""
    else
        write_banner "Running API Gateway E2E Tests"
        bash "$scriptDir/test-gateway.sh"
    fi
fi

# ----------------------------------------------------------
# Final summary
# ----------------------------------------------------------
write_banner "All Tests Complete"

echo -e "${GRAY}  Services tested:${NC}"
if [ "$gateway" = false ]; then
    [ "$auth_running" = true ] && echo -e "    ${GREEN}✅ Auth Service${NC}"
    [ "$user_running" = true ] && echo -e "    ${GREEN}✅ User Service${NC}"
    [ "$trip_running" = true ] && echo -e "    ${GREEN}✅ Trip Service${NC}"
    [ "$booking_running" = true ] && echo -e "    ${GREEN}✅ Booking Service${NC}"
    [ "$payment_running" = true ] && echo -e "    ${GREEN}✅ Payment Service${NC}"
fi
if [ "$gateway" = true ] || [ "$all" = true ]; then
    [ "$gateway_running" = true ] && echo -e "    ${GREEN}✅ API Gateway (E2E)${NC}"
fi

echo ""

# Cleanup credentials file on successful completion
if [ -f "$LESSGO_CREDS_FILE" ]; then
    echo -e "${GRAY}  Cleaning up credentials file${NC}"
    rm -f "$LESSGO_CREDS_FILE"
fi
