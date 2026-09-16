#!/usr/bin/env bash
# Install defensive ELK stack (separate from vulnerable E7 Elasticsearch).
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

SERVICE_DIR="$SCRIPT_DIR/services/elk"
COMPOSE_FILE="$SERVICE_DIR/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/elk"

mv_require_file "$COMPOSE_FILE"
mv_require_file "$SERVICE_DIR/elasticsearch.yml"
mv_require_file "$SERVICE_DIR/kibana.yml"
mv_require_file "$SERVICE_DIR/filebeat.yml"

mkdir -p "$SERVICE_STATE/filebeat-data"
chmod 700 "$SERVICE_STATE"

mv_log "starting defensive ELK stack with project $ELK_PROJECT"
mv_compose "$ELK_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$ELK_ES_CONTAINER" 180
mv_wait_healthy "$ELK_KIBANA_CONTAINER" 180
mv_log "defensive ELK ready: Kibana on 127.0.0.1:5601"
