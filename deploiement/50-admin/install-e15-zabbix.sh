#!/usr/bin/env bash
# Install E15, the healthy Zabbix appliance isolated in ADMIN.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"
COMPOSE_FILE="$SCRIPT_DIR/services/e15/compose.yaml"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SCRIPT_DIR/services/e15/config/zabbix_server.conf"

mv_log "starting E15 healthy Zabbix appliance with project $E15_PROJECT"
mv_compose "$E15_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E15_CONTAINER" 300
mv_log "E15 Zabbix is healthy"
