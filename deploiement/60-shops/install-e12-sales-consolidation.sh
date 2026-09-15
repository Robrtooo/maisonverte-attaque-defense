#!/usr/bin/env bash
# Install E12 XXL-JOB sales consolidation with executor /run exposed internally.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

COMPOSE_FILE="$SCRIPT_DIR/services/e12/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e12"
SECRETS_SCRIPT="$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"

mv_require_file "$SECRETS_SCRIPT"
mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E12 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

export MV_E12_DB_PASSWORD MV_E11_BASIC_USER MV_E11_BASIC_PASSWORD
MV_E12_DB_PASSWORD="$($SECRETS_SCRIPT e12-mysql-root-password)"
MV_E11_BASIC_USER="$($SECRETS_SCRIPT e11-mongo-express-user 12)"
MV_E11_BASIC_PASSWORD="$($SECRETS_SCRIPT e11-mongo-express-password)"
printf 'mongo-express Basic Auth: %s:%s\n' "$MV_E11_BASIC_USER" "$MV_E11_BASIC_PASSWORD" >"$SERVICE_STATE/e11-mongo-express-credential.txt"
chmod 600 "$SERVICE_STATE/e11-mongo-express-credential.txt"

mv_log "starting E12 sales consolidation with project $E12_PROJECT"
mv_compose "$E12_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy pos-consol-shops01-db 120
mv_wait_healthy pos-consol-shops01-admin 120
mv_wait_healthy "$E12_CONTAINER" 120

MV_E12_DB_PASSWORD="$MV_E12_DB_PASSWORD" "$SCRIPT_DIR/services/e12/seed-sales.sh"
mv_log "E12 sales consolidation is healthy and seeded"
