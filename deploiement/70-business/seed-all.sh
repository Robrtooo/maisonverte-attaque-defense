#!/usr/bin/env bash
# Import versioned datasets into the existing MaisonVerte business services.
set -Eeuo pipefail
WORKFLOW_VERSION="1.0.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command docker
mv_require_command jq

DATA_DIR="${MV_BUSINESS_DATA_DIR:-$MV_DEPLOY_DIR/data}"
PASSWORD_FILE="$(mv_state_dir)/secrets/e12-mysql-root-password"
for dataset in products.json orders.json clients.json tickets.csv vendors.json accounts.csv; do
  mv_require_file "$DATA_DIR/$dataset"
done

if [[ -n "${MV_E12_DB_PASSWORD:-}" ]]; then
  E12_DB_PASSWORD="$MV_E12_DB_PASSWORD"
else
  mv_require_file "$PASSWORD_FILE"
  E12_DB_PASSWORD="$(<"$PASSWORD_FILE")"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mv_log "importing versioned products into E7"
jq -c '.products[] | {"index":{"_index":"maisonverte","_type":"products","_id":.product_id}}, .' \
  "$DATA_DIR/products.json" >"$TMP_DIR/e7-products.ndjson"
docker cp "$TMP_DIR/e7-products.ndjson" search-srv01:/tmp/mv-products.ndjson
docker exec search-srv01 sh -c \
  "curl -fsS -XPOST 'http://127.0.0.1:9200/_bulk' --data-binary @/tmp/mv-products.ndjson >/dev/null"

mv_log "importing versioned products and orders into E10"
{
  printf '%s\n' 'BEGIN;' 'TRUNCATE orders, products RESTART IDENTITY;'
  jq -r '.products[] | "INSERT INTO products(sku,name,category,price,stock) VALUES (\u0027\(.sku)\u0027,\u0027\(.name)\u0027,\u0027\(.category)\u0027,\(.price_eur),\(.stocks_by_store[0].quantity));"' "$DATA_DIR/products.json"
  jq -r '.orders[] | "INSERT INTO orders(order_id,sku,quantity,status,created_at) VALUES (\u0027\(.order_id)\u0027,\u0027\(.product_id)\u0027,\(.quantity),\u0027\(.status)\u0027,\u0027\(.created_at)\u0027);"' "$DATA_DIR/orders.json"
  printf '%s\n' 'COMMIT;'
} >"$TMP_DIR/e10-business.sql"
docker exec -i catalog-data01 psql -U mv_catalog_admin -d maisonverte -v ON_ERROR_STOP=1 <"$TMP_DIR/e10-business.sql" >/dev/null

mv_log "importing versioned loyalty clients into E11"
docker cp "$DATA_DIR/clients.json" clients-data01-mongo:/tmp/mv-clients.json
docker exec clients-data01-mongo mongo --quiet --eval \
  "db=db.getSiblingDB('maisonverte_clients'); var payload=JSON.parse(cat('/tmp/mv-clients.json')); db.clients.remove({}); db.clients.insert(payload.clients);" >/dev/null

mv_log "importing versioned ticket lines into E12"
docker cp "$DATA_DIR/tickets.csv" pos-consol-shops01-db:/tmp/mv-tickets.csv
docker exec pos-consol-shops01-db mysql --local-infile=1 -uroot -p"$E12_DB_PASSWORD" xxl_job -e \
  "CREATE TABLE IF NOT EXISTS mv_ticket_lines(line_id VARCHAR(16) PRIMARY KEY,ticket_id VARCHAR(16),store_code VARCHAR(16),sale_date DATE,sku VARCHAR(16),quantity INT,unit_price DECIMAL(8,2),line_total DECIMAL(10,2),vendor_id VARCHAR(16)); TRUNCATE mv_ticket_lines; LOAD DATA LOCAL INFILE '/tmp/mv-tickets.csv' INTO TABLE mv_ticket_lines FIELDS TERMINATED BY ',' IGNORE 1 LINES;" >/dev/null

mv_log "depositing dated accounting exports on E9"
docker exec files-srv01 sh -c "mkdir -p /home/share/marketing/exports"
for export_file in "$DATA_DIR"/exports/export-comptable-????-??-??.csv; do
  mv_require_file "$export_file"
  docker cp "$export_file" "files-srv01:/home/share/marketing/exports/$(basename -- "$export_file")"
done

mv_log "validating E16 mounted business data"
docker exec crm-srv01 sh -c \
  "test -s /usr/share/nginx/html/data/clients.json && test -s /usr/share/nginx/html/data/vendors.json && test -s /usr/share/nginx/html/data/accounts.csv && nginx -t"
mv_log "versioned business datasets imported (workflow $WORKFLOW_VERSION)"
