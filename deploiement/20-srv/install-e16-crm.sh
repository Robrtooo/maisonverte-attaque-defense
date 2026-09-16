#!/usr/bin/env bash
# Install E16, the healthy static CRM and campaign viewer.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"
COMPOSE_FILE="$SCRIPT_DIR/services/e16/compose.yaml"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SCRIPT_DIR/services/e16/html/index.html"
mv_require_file "$SCRIPT_DIR/services/e16/html/data/segments.json"
mv_require_file "$MV_DEPLOY_DIR/data/clients.json"
mv_require_file "$MV_DEPLOY_DIR/data/accounts.csv"

mv_log "starting E16 healthy CRM with project $E16_PROJECT"
mv_compose "$E16_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E16_CONTAINER" 60
mv_log "E16 CRM is healthy"
