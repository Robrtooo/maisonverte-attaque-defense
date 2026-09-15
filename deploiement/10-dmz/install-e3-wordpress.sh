#!/usr/bin/env bash
# Install E3 WordPress 4.6 and seed its MaisonVerte content idempotently.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

COMPOSE_FILE="$SCRIPT_DIR/services/e3/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e3"
SECRETS_SCRIPT="$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"

mv_require_file "$SECRETS_SCRIPT"
mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
E3_FLAG="$(mv_flag_value E3)"
printf '%s\n' "$E3_FLAG" >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

export MV_E3_DB_PASSWORD
export MV_E3_ADMIN_PASSWORD
MV_E3_DB_PASSWORD="$($SECRETS_SCRIPT e3-db-password)"
MV_E3_ADMIN_PASSWORD="$($SECRETS_SCRIPT e3-admin-password)"

mv_log "starting E3 WordPress with project $E3_PROJECT"
mv_compose "$E3_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy shop-dmz01-db 90
mv_wait_healthy "$E3_CONTAINER" 120

MV_E3_FLAG="$E3_FLAG" \
MV_E3_DB_PASSWORD="$MV_E3_DB_PASSWORD" \
MV_E3_ADMIN_PASSWORD="$MV_E3_ADMIN_PASSWORD" \
  "$SCRIPT_DIR/services/e3/seed-wordpress.sh"
mv_log "E3 WordPress is healthy and seeded"
