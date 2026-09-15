#!/usr/bin/env bash
# Install E11 mongo-express 0.53.0 and private MongoDB client database.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

COMPOSE_FILE="$SCRIPT_DIR/services/e11/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e11"
SECRETS_SCRIPT="$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"

mv_require_file "$SECRETS_SCRIPT"
mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
E11_FLAG="$(mv_flag_value E11)"
printf '%s\n' "$E11_FLAG" >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

export MV_E11_BASIC_USER MV_E11_BASIC_PASSWORD
MV_E11_BASIC_USER="$($SECRETS_SCRIPT e11-mongo-express-user 12)"
MV_E11_BASIC_PASSWORD="$($SECRETS_SCRIPT e11-mongo-express-password)"

mv_log "starting E11 client database with project $E11_PROJECT"
mv_compose "$E11_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy clients-data01-mongo 90
mv_wait_healthy "$E11_CONTAINER" 120

MV_E11_FLAG="$E11_FLAG" "$SCRIPT_DIR/services/e11/seed-clients.sh"
mv_log "E11 client database is healthy and seeded"
