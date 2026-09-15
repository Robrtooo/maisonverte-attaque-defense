#!/usr/bin/env bash
# Install E10 PostgreSQL catalog/orders database for chain A.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/e10"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e10"
SECRET_HELPER="$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/init/01-schema.sql"
mv_require_file "$SERVICE_DIR/seed-database.sh"
mv_require_file "$SECRET_HELPER"

mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E10 >"$SERVICE_STATE/flag.txt"
E10_DB_PASS="$("$SECRET_HELPER" chain-a-e10-postgres-password 24)"
printf '%s\n' "$E10_DB_PASS" >"$SERVICE_STATE/postgres-password"
chmod 600 "$SERVICE_STATE/flag.txt" "$SERVICE_STATE/postgres-password"

export E10_DB_USER=mv_catalog_admin
export E10_DB_PASS
export E10_DB_NAME=maisonverte

mv_log "starting E10 catalog/orders database with project $E10_PROJECT"
mv_compose "$E10_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E10_CONTAINER" 120
"$SERVICE_DIR/seed-database.sh"
mv_log "E10 catalog/orders database is ready"
