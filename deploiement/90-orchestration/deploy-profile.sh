#!/usr/bin/env bash
# Deploy one RAM-safe MaisonVerte profile.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

profile="${1:-}"
[[ -n "$profile" ]] || mv_die "usage: $0 foundation|dmz|chain-a|chain-b|chain-c|business|detection|stop-heavy"

run() {
  mv_log "run: $*"
  "$@"
}

stop_project() {
  local project="$1" compose="$2"
  [[ -f "$compose" ]] || return 0
  mv_compose "$project" "$compose" down --remove-orphans || true
}

case "$profile" in
  foundation)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --no-images
    run "$MV_DEPLOY_DIR/00-infra/create-networks.sh"
    run "$MV_DEPLOY_DIR/00-infra/generate-tls.sh"
    run "$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"
    ;;
  dmz)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --images mysql:5 vulhub/nginx:1 vulhub/tomcat:8.5.19 vulhub/wordpress:4.6
    run "$MV_DEPLOY_DIR/10-dmz/install-e2-reverse-proxy.sh"
    run "$MV_DEPLOY_DIR/10-dmz/install-e3-wordpress.sh"
    run "$MV_DEPLOY_DIR/10-dmz/install-e4-mobile-api.sh"
    run "$MV_DEPLOY_DIR/10-dmz/install-e5-vendor-portal.sh"
    ;;
  chain-a)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --images vulhub/elasticsearch:1.4.2 vulhub/redis:4.0.14 vulhub/postgres:10.7
    run "$MV_DEPLOY_DIR/20-srv/install-e7-product-search.sh"
    run "$MV_DEPLOY_DIR/20-srv/install-e8-session-cache.sh"
    run "$MV_DEPLOY_DIR/30-data/install-e10-catalog-orders.sh"
    ;;
  chain-b)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --images mysql:5.7 mongo:3.4 vulhub/jenkins:2.441 vulhub/mongo-express:0.53.0 vulhub/xxl-job:2.2.0-admin vulhub/xxl-job:2.2.0-executor
    run "$MV_DEPLOY_DIR/20-srv/install-e14-jenkins.sh"
    run "$MV_DEPLOY_DIR/60-shops/install-e12-sales-consolidation.sh"
    run "$MV_DEPLOY_DIR/30-data/install-e11-client-database.sh"
    ;;
  chain-c)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --images vulhub/ofbiz:18.12.10 vulhub/samba:4.6.3 vulhub/struts2:2.3.30
    run "$MV_DEPLOY_DIR/20-srv/install-e6-backoffice.sh"
    run "$MV_DEPLOY_DIR/20-srv/install-e9-marketing-files.sh"
    run "$MV_DEPLOY_DIR/60-shops/install-e13-wms.sh"
    ;;
  business)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --images nginx:1.27.4-alpine zabbix/zabbix-appliance:alpine-7.0.27
    run "$MV_DEPLOY_DIR/50-admin/install-e15-zabbix.sh"
    run "$MV_DEPLOY_DIR/20-srv/install-e16-crm.sh"
    run "$MV_DEPLOY_DIR/70-business/seed-all.sh"
    ;;
  detection)
    run "$MV_DEPLOY_DIR/00-infra/preflight.sh" --images docker.elastic.co/elasticsearch/elasticsearch:7.17.24 docker.elastic.co/kibana/kibana:7.17.24 docker.elastic.co/beats/filebeat:7.17.24
    run "$MV_DEPLOY_DIR/50-admin/install-elk-detection.sh"
    run "$MV_DEPLOY_DIR/80-detection/configure-suricata-notes.sh"
    ;;
  stop-heavy)
    stop_project mv-e6 "$MV_DEPLOY_DIR/20-srv/services/e6/compose.yaml"
    stop_project mv-e7 "$MV_DEPLOY_DIR/20-srv/services/e7/compose.yaml"
    stop_project mv-e14 "$MV_DEPLOY_DIR/20-srv/services/e14/compose.yaml"
    stop_project mv-e15 "$MV_DEPLOY_DIR/50-admin/services/e15/compose.yaml"
    stop_project mv-elk "$MV_DEPLOY_DIR/50-admin/services/elk/compose.yaml"
    ;;
  *)
    mv_die "unknown profile: $profile"
    ;;
esac
