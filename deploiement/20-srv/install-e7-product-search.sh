#!/usr/bin/env bash
# Install E7 product search (Elasticsearch CVE-2015-1427) for chain A.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/e7"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e7"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/seed-search.sh"

mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E7 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

mv_log "starting E7 product search with project $E7_PROJECT"
mv_compose "$E7_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E7_CONTAINER" 120
"$SERVICE_DIR/seed-search.sh"
mv_log "E7 product search is seeded"
