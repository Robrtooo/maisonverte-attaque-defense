#!/usr/bin/env bash
# R-03: create one deterministic order, back-office record and WMS preparation.
set -Eeuo pipefail
WORKFLOW_VERSION="1.0.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

LOG_DIR="${MV_BUSINESS_LOG_DIR:-$(mv_state_dir)/business/logs}"
mkdir -p "$LOG_DIR"
RUN_AT="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/r03-$RUN_AT.log"
ORDER_ID=CMD-R03-20260915-001
PREPARATION_ID=PREP-R03-20260915-001

log_step() { printf '%s [R-03] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE"; }

log_step "creating boutique order $ORDER_ID"
docker exec shop-dmz01 sh -c \
  "umask 077; mkdir -p /tmp/maisonverte-orders; printf '%s\n' '{\"order_id\":\"$ORDER_ID\",\"client_id\":\"CLI-001\",\"product_id\":\"MV-P001\",\"quantity\":2}' > /tmp/maisonverte-orders/$ORDER_ID.json"
docker exec catalog-data01 psql -U mv_catalog_admin -d maisonverte -v ON_ERROR_STOP=1 -c \
  "INSERT INTO orders(order_id,sku,quantity,status,created_at) VALUES ('$ORDER_ID','MV-P001',2,'payee','2026-09-15') ON CONFLICT (order_id) DO UPDATE SET sku=EXCLUDED.sku,quantity=EXCLUDED.quantity,status=EXCLUDED.status,created_at=EXCLUDED.created_at;" >/dev/null

log_step "recording $ORDER_ID in the E6 back-office interface"
docker exec backoffice-srv01 sh -c \
  "umask 077; mkdir -p /opt/maisonverte/business/orders; printf '%s\n' '{\"order_id\":\"$ORDER_ID\",\"status\":\"payee\",\"product_id\":\"MV-P001\",\"quantity\":2}' > /opt/maisonverte/business/orders/$ORDER_ID.json"

log_step "creating WMS preparation $PREPARATION_ID for $ORDER_ID"
docker exec wms-shops01 sh -c \
  "umask 077; mkdir -p /opt/maisonverte/business/preparations; printf '%s\n' '{\"preparation_id\":\"$PREPARATION_ID\",\"order_id\":\"$ORDER_ID\",\"status\":\"a_preparer\"}' > /opt/maisonverte/business/preparations/$PREPARATION_ID.json"

log_step "flow complete: $ORDER_ID -> $PREPARATION_ID"
