#!/usr/bin/env bash
# Read-only detection checks.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"
mv_require_command docker

failures=0
check_container() {
  local name="$1"
  if docker inspect "$name" >/dev/null 2>&1; then
    mv_log "OK container exists: $name"
  else
    mv_log "MISS container: $name"
    failures=$((failures + 1))
  fi
}

check_container "$ELK_ES_CONTAINER"
check_container "$ELK_KIBANA_CONTAINER"
check_container "$ELK_FILEBEAT_CONTAINER"

if docker exec "$ELK_ES_CONTAINER" curl -fsS http://127.0.0.1:9200/_cat/indices >/dev/null 2>&1; then
  mv_log "OK Elasticsearch query"
else
  mv_log "MISS Elasticsearch query"
  failures=$((failures + 1))
fi

if docker exec "$ELK_FILEBEAT_CONTAINER" filebeat test output --strict.perms=false -e >/dev/null 2>&1; then
  mv_log "OK Filebeat output"
else
  mv_log "MISS Filebeat output"
  failures=$((failures + 1))
fi

mv_log "EveBox manual check: http://192.168.10.30:5636 from internal pivot"
exit "$failures"
