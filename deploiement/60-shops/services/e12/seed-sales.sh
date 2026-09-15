#!/usr/bin/env bash
# Idempotently seed E12 sales-consolidation notes inside the private MySQL DB.
set -Eeuo pipefail

: "${MV_E12_DB_PASSWORD:?MV_E12_DB_PASSWORD is required}"

mysql_exec() {
  docker exec -i pos-consol-shops01-db mysql -uroot -p"$MV_E12_DB_PASSWORD" xxl_job "$@"
}

mysql_exec <<'SQL'
CREATE TABLE IF NOT EXISTS mv_sales_batches (
  batch_id VARCHAR(32) PRIMARY KEY,
  shop_code VARCHAR(16) NOT NULL,
  business_day DATE NOT NULL,
  tickets INT NOT NULL,
  gross_cents INT NOT NULL,
  status VARCHAR(32) NOT NULL
);
INSERT INTO mv_sales_batches (batch_id, shop_code, business_day, tickets, gross_cents, status) VALUES
  ('MV-B-2026-09-01-LYO', 'LYO', '2026-09-01', 73, 184320, 'validated'),
  ('MV-B-2026-09-01-NTE', 'NTE', '2026-09-01', 51, 129980, 'validated'),
  ('MV-B-2026-09-02-PAR', 'PAR', '2026-09-02', 88, 215440, 'validated')
ON DUPLICATE KEY UPDATE tickets=VALUES(tickets), gross_cents=VALUES(gross_cents), status=VALUES(status);

CREATE TABLE IF NOT EXISTS mv_chain_notes (
  note_key VARCHAR(64) PRIMARY KEY,
  note_value TEXT NOT NULL
);
INSERT INTO mv_chain_notes (note_key, note_value) VALUES
  ('e11-basic-auth-file', '/opt/maisonverte/e11-mongo-express-credential.txt'),
  ('e11-target', 'http://clients-data01:8081/checkValid')
ON DUPLICATE KEY UPDATE note_value=VALUES(note_value);
SQL
