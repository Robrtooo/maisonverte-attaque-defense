#!/usr/bin/env bash
# Install E9 Samba marketing files for Chain C.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/e9"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e9"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/smb.conf"
mv_require_file "$SERVICE_DIR/content/share/procedure-wms.txt"

mkdir -p "$SERVICE_STATE/share"
chmod 700 "$SERVICE_STATE"
cp -a "$SERVICE_DIR/content/share/." "$SERVICE_STATE/share/"
find "$SERVICE_STATE/share" -type d -exec chmod 0777 {} +
find "$SERVICE_STATE/share" -type f -exec chmod 0666 {} +

umask 077
mv_flag_value E9 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

mv_log "starting E9 Samba marketing files with project $E9_PROJECT"
mv_compose "$E9_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E9_CONTAINER" 120
mv_log "E9 Samba marketing files are available"
