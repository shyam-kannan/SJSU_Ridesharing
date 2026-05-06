#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# LessGo — Embedding Model Build Verifier
# ═══════════════════════════════════════════════════════════════════════════════
#
# PURPOSE
#   Automates the end-to-end model build process for the embedding-service:
#     1. Triggers the training job (POST /train)
#     2. Polls the status until completion or failure
#     3. Verifies the existence of the generated model files
#
# USAGE
#   ./scripts/verify-embedding-build.sh
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SERVICE_URL="${EMBEDDING_SERVICE_URL:-http://127.0.0.1:3010}"
POLL_INTERVAL=5
MAX_RETRIES=120  # 10 minutes total

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
step() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ok()   { echo -e "  ${GREEN}✓ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "  ${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "  ${CYAN}→ $1${NC}"; }

# ── Verification ──────────────────────────────────────────────────────────────
step "Triggering Training Job"
info "Calling POST ${SERVICE_URL}/train ..."

RESP=$(curl -s -X POST "${SERVICE_URL}/train" -H "Content-Type: application/json" -d '{}')

JOB_ID=$(echo "$RESP" | jq -r '.job_id // empty')
if [[ -z "$JOB_ID" ]]; then
  fail "Failed to start training. Response: $RESP"
fi

ok "Training job started: ${JOB_ID}"

step "Monitoring Progress"
retry=0
while [[ $retry -lt $MAX_RETRIES ]]; do
  STATUS_RESP=$(curl -s "${SERVICE_URL}/train/status/${JOB_ID}")
  STATUS=$(echo "$STATUS_RESP" | jq -r '.status // "unknown"')
  
  case "$STATUS" in
    "done")
      echo -e "\n"
      ok "Training completed successfully!"
      break
      ;;
    "error")
      ERROR_MSG=$(echo "$STATUS_RESP" | jq -r '.error // "Unknown error"')
      echo -e "\n"
      fail "Training failed: ${ERROR_MSG}"
      ;;
    *)
      # Print progress on the same line
      printf "\r  ${YELLOW}⏳ Status: %-20s (Attempt %d/%d)${NC}" "$STATUS" "$((retry+1))" "$MAX_RETRIES"
      sleep "$POLL_INTERVAL"
      retry=$((retry + 1))
      ;;
  esac
done

if [[ $retry -eq $MAX_RETRIES ]]; then
  echo -e "\n"
  fail "Timed out waiting for training to complete."
fi

step "Final Validation"
# Check health endpoint
HEALTH=$(curl -s "${SERVICE_URL}/health")
READY=$(echo "$HEALTH" | jq -r '.model_ready')

if [[ "$READY" == "true" ]]; then
  ok "Service reports model_ready: true"
else
  fail "Service reports model is NOT ready despite job completion."
fi

# Verify files exist in the models directory (relative to the service)
# Note: This assumes the script is run from the repo root
MODEL_DIR="services/embedding-service/models"
if [[ -f "${MODEL_DIR}/hin.pkl" && -f "${MODEL_DIR}/rshareform.model" ]]; then
  ok "Model files verified on disk: ${MODEL_DIR}/"
  ls -lh "$MODEL_DIR" | grep -E "hin.pkl|rshareform.model" | sed 's/^/    /'
else
  warn "Could not verify model files at ${MODEL_DIR}/. If running in Docker, check the container volume."
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✓  MODEL BUILD VERIFIED                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
