#!/usr/bin/env bash
# Read-only smoke test for the complete MaisonVerte lab. Run on vulndb.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

WAN_HOST="${MV_WAN_HOST:-10.85.4.10}"
INTERNAL_HOST="${MV_INTERNAL_HOST:-192.168.10.50}"
EVEBOX_URL="${MV_EVEBOX_URL:-http://192.168.10.30:5636/}"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '[ OK ] %s\n' "$1"; }
ko() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$1" >&2; }

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else ko "$label"; fi
}

print_endpoints() {
  cat <<EOF
PUBLIC (VPN -> OPNsense NAT -> E2)
  https://shop.maisonverte.fr/       -> ${WAN_HOST}:443 -> E3 WordPress
  https://api.maisonverte.fr/health -> ${WAN_HOST}:443 -> E4 API
  https://vendeurs.maisonverte.fr/  -> ${WAN_HOST}:443 -> E5 Tomcat
  https://cache.maisonverte.fr/     -> ${WAN_HOST}:443 -> E2 Nginx

DEFENSE / ADMIN
  ${EVEBOX_URL} -> EveBox, depuis reseau interne
  http://127.0.0.1:5601/            -> Kibana, depuis vulndb ou tunnel SSH

INTERNAL CONTAINER ENDPOINTS (not published on host)
  E6  https://backoffice-srv01:8443
  E7  http://search-srv01:9200
  E8  cache-srv01:6379              Redis
  E9  files-srv01:445               SMB
  E10 catalog-data01:5432           PostgreSQL
  E11 http://clients-data01:8081    mongo-express
  E12 http://pos-consol-shops01-admin:8080/xxl-job-admin
  E12 pos-consol-shops01:9999       executor
  E13 http://wms-shops01:8080
  E14 http://deploy-srv01:8080/jenkins
  E15 http://supervision-admin01:8080
  E15 supervision-admin01-server:10051
  E16 http://crm-srv01:80/health
  ELK http://elk-admin01-es:9200
EOF
}

http_ok() {
  local target="$1" host="$2" path="$3" code
  code="$(curl -ksS --connect-timeout 4 --max-time 10 -o /dev/null -w '%{http_code}' \
    --resolve "${host}:443:${target}" "https://${host}${path}" 2>/dev/null || true)"
  [[ "$code" =~ ^(2|3)[0-9][0-9]$ ]]
}

container_ok() {
  local name="$1" running health
  running="$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)"
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name" 2>/dev/null || true)"
  [[ "$running" == true && ( -z "$health" || "$health" == healthy ) ]]
}

published_ports_ok() {
  local actual name project
  actual="$({
    while IFS= read -r name; do
      project="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null || true)"
      [[ "$project" == mv-* ]] || continue
      [[ -n "$(docker port "$name" 2>/dev/null)" ]] && printf '%s\n' "$name"
    done < <(docker ps --format '{{.Names}}')
  } | sort)"
  [[ "$actual" == $'cache-dmz01\nelk-admin01-kibana' ]]
}

e7_data_ok() {
  local count
  count="$(docker exec search-srv01 curl -fsS http://127.0.0.1:9200/maisonverte/_count 2>/dev/null \
    | sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p')"
  [[ "$count" =~ ^[0-9]+$ ]] && (( count >= 41 ))
}

e10_data_ok() {
  [[ "$(docker exec catalog-data01 psql -U mv_catalog_admin -d maisonverte -Atc \
    'SELECT (SELECT count(*) FROM products), (SELECT count(*) FROM orders);' 2>/dev/null)" == '40|60' ]]
}

e11_data_ok() {
  [[ "$(docker exec clients-data01-mongo mongo maisonverte_clients --quiet --eval \
    'db.clients.count()' 2>/dev/null | tr -d '\r')" == '30' ]]
}

e12_data_ok() {
  local secret_file="$MV_DEPLOY_DIR/state/secrets/e12-mysql-root-password" password
  [[ -s "$secret_file" ]] || return 1
  password="$(<"$secret_file")"
  [[ "$(docker exec pos-consol-shops01-db mysql -N -uroot -p"$password" xxl_job \
    -e 'SELECT COUNT(*) FROM mv_ticket_lines' 2>/dev/null | tr -d '\r')" == '200' ]]
}

elk_data_ok() {
  local total
  total="$(docker exec elk-admin01-es curl -fsS \
    'http://127.0.0.1:9200/_cat/indices/maisonverte-docker-*?h=docs.count' 2>/dev/null \
    | awk '{sum += $1} END {print sum + 0}')"
  [[ "$total" =~ ^[0-9]+$ ]] && (( total > 0 ))
}

if [[ "${1:-}" == "--list" ]]; then
  print_endpoints
  exit 0
fi

mv_require_command docker
mv_require_command curl
print_endpoints
printf '\nCONTAINER HEALTH\n'

containers=(
  cache-dmz01 shop-dmz01-db shop-dmz01 mobile-dmz01 market-dmz01
  backoffice-srv01 search-srv01 cache-srv01 files-srv01 catalog-data01
  clients-data01 clients-data01-mongo pos-consol-shops01-db
  pos-consol-shops01-admin pos-consol-shops01 wms-shops01 deploy-srv01
  supervision-admin01-db supervision-admin01-server supervision-admin01
  crm-srv01 elk-admin01-es elk-admin01-kibana elk-admin01-filebeat
)
for container in "${containers[@]}"; do
  check "$container running + healthy" container_ok "$container"
done

printf '\nNETWORK ENDPOINTS\n'
for host_path in \
  'shop.maisonverte.fr /' \
  'api.maisonverte.fr /health' \
  'vendeurs.maisonverte.fr /' \
  'cache.maisonverte.fr /'; do
  read -r host path <<<"$host_path"
  check "internal TLS ${host}${path}" http_ok "$INTERNAL_HOST" "$host" "$path"
  check "WAN/NAT TLS ${host}${path}" http_ok "$WAN_HOST" "$host" "$path"
done
check "EveBox ${EVEBOX_URL}" curl -fsS --connect-timeout 4 --max-time 10 "$EVEBOX_URL"
check "Kibana http://127.0.0.1:5601/api/status" curl -fsS --max-time 10 http://127.0.0.1:5601/api/status
check "only E2 and Kibana publish host ports" published_ports_ok

printf '\nFUNCTIONAL DATA\n'
check "E7 search index has at least 41 documents" e7_data_ok
check "E8 Redis answers PONG" docker exec cache-srv01 redis-cli PING
check "E10 has 40 products and 60 orders" e10_data_ok
check "E11 has 30 clients" e11_data_ok
check "E12 has 200 ticket lines" e12_data_ok
check "E16 health and mounted clients data" docker exec crm-srv01 sh -c \
  'wget -qO- http://127.0.0.1/health >/dev/null && test -s /srv/maisonverte-data/clients.json'
check "ELK has collected Docker documents" elk_data_ok
check "Filebeat output reaches Elasticsearch" docker exec elk-admin01-filebeat \
  filebeat test output --strict.perms=false -e

printf '\nSUMMARY: %d OK, %d FAIL\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
