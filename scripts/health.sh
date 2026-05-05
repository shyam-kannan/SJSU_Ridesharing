#!/usr/bin/env bash
# scripts/health.sh — check every LessGo service and print a status table.
#
# Usage:
#   ./scripts/health.sh            — check all services
#   ./scripts/health.sh gateway    — check a single service by name
#   ./scripts/health.sh --prod     — check against the production gateway URL

set -euo pipefail

PROD_GATEWAY="${PROD_GATEWAY_URL:-http://136.109.119.177}"
BASE_URL="http://localhost"

# Parse flags
PROD_MODE=false
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --prod) PROD_MODE=true ;;
    *)      FILTER="$arg"  ;;
  esac
done

# Colour helpers
_bold=""  _reset=""  _green=""  _red=""  _yellow=""
if command -v tput &>/dev/null && tput colors &>/dev/null; then
  _bold=$(tput bold)
  _reset=$(tput sgr0)
  _green=$(tput setaf 2)
  _red=$(tput setaf 1)
  _yellow=$(tput setaf 3)
fi

PASS=0
FAIL=0

check() {
  local name="$1"
  local url="$2"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" == "200" ]]; then
    printf "  ${_green}✓${_reset} %-26s %s\n" "$name" "$url"
    (( PASS++ )) || true
  else
    printf "  ${_red}✗${_reset} %-26s %s  ${_yellow}(HTTP $http_code)${_reset}\n" "$name" "$url"
    (( FAIL++ )) || true
  fi
}

echo ""
echo "${_bold}LessGo — Service Health Check${_reset}"
echo "$(date)"
echo ""

if $PROD_MODE; then
  echo "${_yellow}Mode: production${_reset} ($PROD_GATEWAY)"
  echo ""
  check "API Gateway (prod)" "$PROD_GATEWAY/health"
else
  echo "Mode: local"
  echo ""

  declare -A LOCAL_SERVICES=(
    ["API Gateway"]="3000"
    ["Auth Service"]="3001"
    ["User Service"]="3002"
    ["Trip Service"]="3003"
    ["Booking Service"]="3004"
    ["Payment Service"]="3005"
    ["Notification Service"]="3006"
    ["Cost Calculation"]="3009"
  )

  declare -a ORDER=(
    "API Gateway"
    "Auth Service"
    "User Service"
    "Trip Service"
    "Booking Service"
    "Payment Service"
    "Notification Service"
    "Cost Calculation"
  )

  for name in "${ORDER[@]}"; do
    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && continue
    port="${LOCAL_SERVICES[$name]}"
    check "$name" "${BASE_URL}:${port}/health"
  done

  # Optional Python services (don't count failures)
  echo ""
  echo "  Optional Python services:"
  for entry in "Embedding Service:3010" "Grouping Service:8000" "Routing Service:8002" "Safety Service:8005"; do
    svc="${entry%%:*}"
    port="${entry##*:}"
    [[ -n "$FILTER" && "$svc" != *"$FILTER"* ]] && continue
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "${BASE_URL}:${port}/health" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
      printf "  ${_green}✓${_reset} %-26s %s\n" "$svc" "${BASE_URL}:${port}/health"
    else
      printf "  ${_yellow}–${_reset} %-26s not running (optional)\n" "$svc"
    fi
  done
fi

echo ""
echo "─────────────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  echo "${_green}${_bold}All $PASS services healthy.${_reset}"
else
  echo "${_red}${_bold}$FAIL service(s) unhealthy${_reset}, $PASS healthy."
fi
echo ""
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
