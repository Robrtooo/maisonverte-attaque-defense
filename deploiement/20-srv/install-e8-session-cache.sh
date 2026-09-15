#!/usr/bin/env bash
# Install E8 Redis session/cache service for chain A.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/e8"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e8"
SECRET_HELPER="$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/seed-cache.sh"
mv_require_file "$SECRET_HELPER"

mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E8 >"$SERVICE_STATE/flag.txt"
E10_DB_PASS="$("$SECRET_HELPER" chain-a-e10-postgres-password 24)"
printf '%s\n' "$E10_DB_PASS" >"$SERVICE_STATE/e10-postgres-password"
chmod 600 "$SERVICE_STATE/flag.txt" "$SERVICE_STATE/e10-postgres-password"

export E10_DB_PASS

mv_log "starting E8 session cache with project $E8_PROJECT"
mv_compose "$E8_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E8_CONTAINER" 60
"$SERVICE_DIR/seed-cache.sh"
mv_log "E8 session cache is reset and seeded"
