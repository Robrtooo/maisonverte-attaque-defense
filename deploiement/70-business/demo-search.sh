#!/usr/bin/env bash
# R-04: compare the first catalog references in E10 and E7.
set -Eeuo pipefail
WORKFLOW_VERSION="1.0.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command jq
LOG_DIR="${MV_BUSINESS_LOG_DIR:-$(mv_state_dir)/business/logs}"
mkdir -p "$LOG_DIR"
RUN_AT="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/r04-$RUN_AT.log"

log_step() { printf '%s [R-04] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE"; }

catalog_refs="$(docker exec catalog-data01 psql -U mv_catalog_admin -d maisonverte -Atc "SELECT sku FROM products ORDER BY sku LIMIT 3")"
search_json="$(docker exec search-srv01 sh -c "curl -fsS 'http://127.0.0.1:9200/maisonverte/products/_search?q=sku:MV-P00*&size=40'")"
search_refs="$(printf '%s' "$search_json" | jq -r '.hits.hits[]._source.sku' | sort | head -n 3)"

if [[ "$catalog_refs" != "$search_refs" ]]; then
  log_step "catalog/search mismatch"
  printf 'catalog:\n%s\nsearch:\n%s\n' "$catalog_refs" "$search_refs" >&2
  exit 1
fi

log_step "coherent references: $(tr '\n' ' ' <<<"$catalog_refs")"
