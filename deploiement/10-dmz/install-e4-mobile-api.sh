#!/usr/bin/env bash
# Install E4, the healthy read-only mobile API.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"
COMPOSE_FILE="$SCRIPT_DIR/services/e4/compose.yaml"

mv_log "starting E4 mobile API with project $E4_PROJECT"
mv_compose "$E4_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E4_CONTAINER" 60
mv_log "E4 mobile API is healthy"
