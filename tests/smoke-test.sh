#!/usr/bin/env bash
# ============================================================================
# Smoke Test Script for Observability Solution Accelerator
# Validates that all deployed resources exist and are correctly configured.
#
# Usage:
#   ./tests/smoke-test.sh <resource-group> <customer-name> [--sentinel] [--iot]
#
# Prerequisites:
#   - Azure CLI (az) logged in with appropriate permissions
#   - jq installed
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass()  { echo -e "${GREEN}✓ PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail()  { echo -e "${RED}✗ FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
warn()  { echo -e "${YELLOW}⚠ WARN${NC}: $1"; WARN=$((WARN + 1)); }
info()  { echo -e "  ℹ $1"; }

# ---------- Parse arguments ----------
RG="${1:?Usage: smoke-test.sh <resource-group> <customer-name> [--sentinel] [--iot]}"
CUSTOMER="${2:?Usage: smoke-test.sh <resource-group> <customer-name> [--sentinel] [--iot]}"
CHECK_SENTINEL=false
CHECK_IOT=false

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sentinel) CHECK_SENTINEL=true ;;
    --iot)      CHECK_IOT=true ;;
    *)          echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

echo "============================================"
echo " Observability Accelerator Smoke Test"
echo " RG: $RG | Customer: $CUSTOMER"
echo "============================================"
echo ""

# ---------- 1. Resource Group ----------
echo "--- Resource Group ---"
if az group show --name "$RG" --output none 2>/dev/null; then
  pass "Resource group '$RG' exists"
else
  fail "Resource group '$RG' not found"
  echo "Cannot continue without resource group."
  exit 1
fi

# ---------- 2. Log Analytics Workspace ----------
echo ""
echo "--- Log Analytics Workspace ---"
WS_NAME="la-${CUSTOMER}-obs"
WS=$(az monitor log-analytics workspace show --resource-group "$RG" --workspace-name "$WS_NAME" 2>/dev/null || echo "")
if [[ -n "$WS" ]]; then
  pass "Log Analytics workspace '$WS_NAME' exists"
  SKU=$(echo "$WS" | jq -r '.sku.name')
  RETENTION=$(echo "$WS" | jq -r '.retentionInDays')
  info "SKU: $SKU | Retention: ${RETENTION} days"
else
  fail "Log Analytics workspace '$WS_NAME' not found"
fi

# ---------- 3. Data Collection Rules ----------
echo ""
echo "--- Data Collection Rules ---"
DCRS=$(az monitor data-collection rule list --resource-group "$RG" --query "[].name" -o tsv 2>/dev/null || echo "")
if echo "$DCRS" | grep -qi "windows"; then
  pass "Windows DCR found"
else
  fail "Windows DCR not found"
fi
if echo "$DCRS" | grep -qi "linux"; then
  pass "Linux DCR found"
else
  fail "Linux DCR not found"
fi

# ---------- 4. Application Insights ----------
echo ""
echo "--- Application Insights ---"
AI_RESOURCES=$(az monitor app-insights component list --resource-group "$RG" --query "[].name" -o tsv 2>/dev/null || echo "")
if [[ -n "$AI_RESOURCES" ]]; then
  AI_COUNT=$(echo "$AI_RESOURCES" | wc -l)
  pass "Application Insights found ($AI_COUNT instance(s))"
  echo "$AI_RESOURCES" | while read -r name; do
    info "  - $name"
  done
else
  warn "No Application Insights instances found (expected if app_insights_apps=[])"
fi

# ---------- 5. Action Groups ----------
echo ""
echo "--- Action Groups ---"
AGS=$(az monitor action-group list --resource-group "$RG" --query "[].name" -o tsv 2>/dev/null || echo "")
for expected in "ag-${CUSTOMER}-critical" "ag-${CUSTOMER}-warning" "ag-${CUSTOMER}-automation"; do
  if echo "$AGS" | grep -q "$expected"; then
    pass "Action group '$expected' exists"
  else
    fail "Action group '$expected' not found"
  fi
done

# ---------- 6. Alert Rules ----------
echo ""
echo "--- Alert Rules ---"
ALERTS=$(az monitor scheduled-query list --resource-group "$RG" --query "[].name" -o tsv 2>/dev/null || echo "")
if [[ -n "$ALERTS" ]]; then
  ALERT_COUNT=$(echo "$ALERTS" | wc -l)
  pass "Alert rules found ($ALERT_COUNT rule(s))"
  echo "$ALERTS" | while read -r name; do
    info "  - $name"
  done
else
  fail "No alert rules found"
fi

# ---------- 7. Azure Policy Assignments ----------
echo ""
echo "--- Azure Policy Assignments ---"
SUB_ID=$(az account show --query id -o tsv)
POLICIES=$(az policy assignment list --scope "/subscriptions/$SUB_ID" --query "[?contains(displayName, '${CUSTOMER}')].displayName" -o tsv 2>/dev/null || echo "")
if [[ -n "$POLICIES" ]]; then
  POL_COUNT=$(echo "$POLICIES" | wc -l)
  pass "Policy assignments found ($POL_COUNT assignment(s))"
else
  warn "No customer-specific policy assignments found (may use different naming)"
fi

# ---------- 8. Sentinel (optional) ----------
if $CHECK_SENTINEL; then
  echo ""
  echo "--- Microsoft Sentinel ---"
  SENTINEL=$(az sentinel onboarding-state list --resource-group "$RG" --workspace-name "$WS_NAME" 2>/dev/null || echo "")
  if [[ -n "$SENTINEL" ]] && echo "$SENTINEL" | jq -e '.value | length > 0' >/dev/null 2>&1; then
    pass "Sentinel is onboarded to workspace"
  else
    fail "Sentinel not onboarded"
  fi

  RULES=$(az sentinel alert-rule list --resource-group "$RG" --workspace-name "$WS_NAME" --query "length(@)" 2>/dev/null || echo "0")
  if [[ "$RULES" -gt 0 ]]; then
    pass "Sentinel analytics rules found ($RULES rule(s))"
  else
    warn "No Sentinel analytics rules found"
  fi
fi

# ---------- 9. IoT Hub (optional) ----------
if $CHECK_IOT; then
  echo ""
  echo "--- IoT Hub ---"
  IOT_NAME="iot-${CUSTOMER}-obs"
  IOT=$(az iot hub show --name "$IOT_NAME" 2>/dev/null || echo "")
  if [[ -n "$IOT" ]]; then
    pass "IoT Hub '$IOT_NAME' exists"
    IOT_SKU=$(echo "$IOT" | jq -r '.sku.name')
    info "SKU: $IOT_SKU"
  else
    fail "IoT Hub '$IOT_NAME' not found"
  fi
fi

# ---------- 10. Data Ingestion Check ----------
echo ""
echo "--- Data Ingestion (Heartbeat) ---"
if [[ -n "$WS" ]]; then
  WS_ID=$(echo "$WS" | jq -r '.customerId')
  HEARTBEAT=$(az monitor log-analytics query --workspace "$WS_ID" --analytics-query "Heartbeat | summarize count() | project HeartbeatCount=count_" --timespan PT1H 2>/dev/null || echo "")
  if [[ -n "$HEARTBEAT" ]] && echo "$HEARTBEAT" | jq -e '.[0].HeartbeatCount | tonumber > 0' >/dev/null 2>&1; then
    HB_COUNT=$(echo "$HEARTBEAT" | jq -r '.[0].HeartbeatCount')
    pass "Heartbeat data flowing ($HB_COUNT records in last hour)"
  else
    warn "No Heartbeat data in last hour (VMs may not have AMA yet)"
  fi
fi

# ---------- Summary ----------
echo ""
echo "============================================"
echo " RESULTS: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo "============================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
