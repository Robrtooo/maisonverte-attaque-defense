#!/usr/bin/env bash
# Install E2, the sole public TLS endpoint and reverse proxy for the DMZ.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

COMPOSE_FILE="$SCRIPT_DIR/services/e2/compose.yaml"
TLS_DIR="$(mv_state_dir)/tls"
SERVICE_STATE="$(mv_state_dir)/services/e2"

mv_require_file "$TLS_DIR/maisonverte.crt"
mv_require_file "$TLS_DIR/maisonverte.key"
mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E2 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

mv_log "starting E2 reverse proxy with project $E2_PROJECT"
mv_compose "$E2_PROJECT" "$COMPOSE_FILE" up -d --build
mv_wait_healthy "$E2_CONTAINER" 60
mv_log "E2 reverse proxy is healthy"
