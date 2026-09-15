#!/usr/bin/env bash
# Install E5, the Tomcat 8.5.19 vendor portal with PUT writes enabled.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

COMPOSE_FILE="$SCRIPT_DIR/services/e5/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e5"

mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E5 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

mv_log "starting E5 vendor portal with project $E5_PROJECT"
mv_compose "$E5_PROJECT" "$COMPOSE_FILE" up -d --build
mv_wait_healthy "$E5_CONTAINER" 90
mv_log "E5 vendor portal is healthy"
