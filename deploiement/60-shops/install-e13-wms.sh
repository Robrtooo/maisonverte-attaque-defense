#!/usr/bin/env bash
# Install E13 Struts2 WMS as the final Chain C service.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/e13"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e13"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/content/wms-profile.txt"

mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E13 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

mv_log "starting E13 Struts2 WMS with project $E13_PROJECT"
mv_compose "$E13_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E13_CONTAINER" 180
mv_log "E13 Struts2 WMS is healthy"
