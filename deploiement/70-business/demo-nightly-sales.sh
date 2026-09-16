#!/usr/bin/env bash
# R-05: load one store's ticket lines into E12 and deposit a dated E9 export.
set -Eeuo pipefail
WORKFLOW_VERSION="1.0.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

DATA_DIR="${MV_BUSINESS_DATA_DIR:-$MV_DEPLOY_DIR/data}"
LOG_DIR="${MV_BUSINESS_LOG_DIR:-$(mv_state_dir)/business/logs}"
PASSWORD_FILE="$(mv_state_dir)/secrets/e12-mysql-root-password"
TICKETS_FILE="$DATA_DIR/tickets.csv"
EXPORT_FILE="$DATA_DIR/exports/export-comptable-2026-08-31.csv"
BATCH_ID=LOT-R05-20260915-MAG001

mv_require_file "$TICKETS_FILE"
mv_require_file "$EXPORT_FILE"
if [[ -n "${MV_E12_DB_PASSWORD:-}" ]]; then
  E12_DB_PASSWORD="$MV_E12_DB_PASSWORD"
else
  mv_require_file "$PASSWORD_FILE"
  E12_DB_PASSWORD="$(<"$PASSWORD_FILE")"
fi
mkdir -p "$LOG_DIR"
RUN_AT="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/r05-$RUN_AT.log"
STORE_TICKETS="$(mktemp)"
trap 'rm -f "$STORE_TICKETS"' EXIT

log_step() { printf '%s [R-05] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE"; }

awk -F, 'NR == 1 || $3 == "MAG001"' "$TICKETS_FILE" >"$STORE_TICKETS"
ticket_lines=$(( $(wc -l <"$STORE_TICKETS") - 1 ))
[[ "$ticket_lines" -gt 0 ]] || mv_die "no MAG001 ticket lines found"

log_step "loading $ticket_lines MAG001 ticket lines as $BATCH_ID"
docker cp "$STORE_TICKETS" pos-consol-shops01-db:/tmp/r05-mag001.csv
docker exec pos-consol-shops01-db mysql --local-infile=1 -uroot -p"$E12_DB_PASSWORD" xxl_job -e \
  "CREATE TABLE IF NOT EXISTS mv_ticket_lines(line_id VARCHAR(16) PRIMARY KEY,ticket_id VARCHAR(16),store_code VARCHAR(16),sale_date DATE,sku VARCHAR(16),quantity INT,unit_price DECIMAL(8,2),line_total DECIMAL(10,2),vendor_id VARCHAR(16)); DELETE FROM mv_ticket_lines WHERE store_code='MAG001'; LOAD DATA LOCAL INFILE '/tmp/r05-mag001.csv' INTO TABLE mv_ticket_lines FIELDS TERMINATED BY ',' IGNORE 1 LINES; INSERT INTO mv_sales_batches(batch_id,shop_code,business_day,tickets,gross_cents,status) SELECT '$BATCH_ID','MAG001','2026-08-31',COUNT(DISTINCT ticket_id),ROUND(SUM(line_total)*100),'validated' FROM mv_ticket_lines WHERE store_code='MAG001' ON DUPLICATE KEY UPDATE tickets=VALUES(tickets),gross_cents=VALUES(gross_cents),status=VALUES(status);" >/dev/null

log_step "depositing dated accounting export on E9 marketing share"
docker exec files-srv01 sh -c "mkdir -p /home/share/marketing/exports"
docker cp "$EXPORT_FILE" files-srv01:/home/share/marketing/exports/export-comptable-2026-08-31.csv
log_step "sales batch $BATCH_ID consolidated and exported"
