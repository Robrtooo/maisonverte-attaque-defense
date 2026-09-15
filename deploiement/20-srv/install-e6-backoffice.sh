#!/usr/bin/env bash
# Install E6 OFBiz back office for Chain C without the upstream JDWP agent.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/e6"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e6"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/content/chain-c-pivot.txt"

mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E6 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

mv_log "starting E6 OFBiz back office with project $E6_PROJECT"
mv_compose "$E6_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E6_CONTAINER" 240
mv_log "E6 OFBiz back office is healthy"
