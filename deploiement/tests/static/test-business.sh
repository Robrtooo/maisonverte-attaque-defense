#!/usr/bin/env bash
# Static and mocked-functional tests for Task 7 (healthy services and business flows).
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"
DATA_DIR="$DEPLOY_DIR/data"

E15_INSTALL="$DEPLOY_DIR/50-admin/install-e15-zabbix.sh"
E16_INSTALL="$DEPLOY_DIR/20-srv/install-e16-crm.sh"
E15_COMPOSE="$DEPLOY_DIR/50-admin/services/e15/compose.yaml"
E16_COMPOSE="$DEPLOY_DIR/20-srv/services/e16/compose.yaml"
E15_CONFIG="$DEPLOY_DIR/50-admin/services/e15/config/zabbix_server.conf"
E16_CONFIG="$DEPLOY_DIR/20-srv/services/e16/nginx.conf"
E16_INDEX="$DEPLOY_DIR/20-srv/services/e16/html/index.html"
E16_SEGMENTS="$DEPLOY_DIR/20-srv/services/e16/html/data/segments.json"
SEED_ALL="$DEPLOY_DIR/70-business/seed-all.sh"
ORDER_FLOW="$DEPLOY_DIR/70-business/demo-order-flow.sh"
SEARCH_FLOW="$DEPLOY_DIR/70-business/demo-search.sh"
SALES_FLOW="$DEPLOY_DIR/70-business/demo-nightly-sales.sh"
SCHEDULES="$DEPLOY_DIR/70-business/install-schedules.sh"

CHECKS=0
FAILURES=0

pass() { CHECKS=$((CHECKS + 1)); printf '[MaisonVerte] PASS: %s\n' "$1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; }
require_condition() { if [[ "$2" -eq 0 ]]; then pass "$1"; else fail "$1"; fi; }
require_file() { [[ -f "$1" ]] && pass "file exists: ${1#"$REPO_ROOT"/}" || fail "file exists: ${1#"$REPO_ROOT"/}"; }

FILES=(
  "$E15_INSTALL" "$E16_INSTALL" "$E15_COMPOSE" "$E16_COMPOSE"
  "$E15_CONFIG" "$E16_CONFIG" "$E16_INDEX" "$E16_SEGMENTS"
  "$DATA_DIR/products.json" "$DATA_DIR/orders.json" "$DATA_DIR/clients.json"
  "$DATA_DIR/tickets.csv" "$DATA_DIR/vendors.json" "$DATA_DIR/accounts.csv"
  "$SEED_ALL" "$ORDER_FLOW" "$SEARCH_FLOW" "$SALES_FLOW" "$SCHEDULES"
)

for file in "${FILES[@]}"; do
  require_file "$file"
done

BASH_FILES=("$E15_INSTALL" "$E16_INSTALL" "$SEED_ALL" "$ORDER_FLOW" "$SEARCH_FLOW" "$SALES_FLOW" "$SCHEDULES")
for file in "${BASH_FILES[@]}"; do
  if [[ -f "$file" ]] && bash -n "$file"; then
    pass "bash -n: ${file#"$REPO_ROOT"/}"
  else
    fail "bash -n: ${file#"$REPO_ROOT"/}"
  fi
done

if command -v jq >/dev/null 2>&1 \
  && [[ -f "$DATA_DIR/products.json" ]] \
  && [[ -f "$DATA_DIR/orders.json" ]] \
  && [[ -f "$DATA_DIR/clients.json" ]] \
  && [[ -f "$DATA_DIR/vendors.json" ]]; then
  require_condition "products dataset has schema version 1.0.0 and exactly 40 products" "$(jq -e '.schema_version == "1.0.0" and (.products | length == 40)' "$DATA_DIR/products.json" >/dev/null; echo $?)"
  require_condition "every product has a visual, description, positive price and 12 store stocks" "$(jq -e 'all(.products[]; (.visual | test("^/images/")) and (.description | length > 10) and (.price_eur > 0) and (.stocks_by_store | length == 12))' "$DATA_DIR/products.json" >/dev/null; echo $?)"
  missing_visual=0
  while IFS= read -r visual; do
    [[ -s "$DATA_DIR$visual" ]] || missing_visual=$((missing_visual + 1))
  done < <(jq -r '.products[].visual' "$DATA_DIR/products.json")
  [[ "$missing_visual" -eq 0 ]] && pass "all 40 product visuals are versioned offline" || fail "all 40 product visuals are versioned offline"
  require_condition "product stocks are differentiated by store" "$(jq -e 'all(.products[]; ([.stocks_by_store[].quantity] | unique | length) > 1)' "$DATA_DIR/products.json" >/dev/null; echo $?)"
  require_condition "orders dataset has schema version 1.0.0 and exactly 60 orders" "$(jq -e '.schema_version == "1.0.0" and (.orders | length == 60)' "$DATA_DIR/orders.json" >/dev/null; echo $?)"
  require_condition "orders span exactly three months" "$(jq -e '[.orders[].created_at[0:7]] | unique | length == 3' "$DATA_DIR/orders.json" >/dev/null; echo $?)"
  require_condition "orders cover all five required statuses" "$(jq -e '[.orders[].status] | unique | sort == ["expediee","litige","payee","preparee","retour"]' "$DATA_DIR/orders.json" >/dev/null; echo $?)"
  require_condition "orders reference declared products and clients" "$(jq -e --slurpfile products "$DATA_DIR/products.json" --slurpfile clients "$DATA_DIR/clients.json" '([ $products[0].products[].product_id ] as $p | [ $clients[0].clients[].client_id ] as $c | all(.orders[]; (.product_id as $id | $p | index($id)) and (.client_id as $id | $c | index($id))))' "$DATA_DIR/orders.json" >/dev/null; echo $?)"
  require_condition "clients dataset has schema version 1.0.0 and exactly 30 loyalty clients" "$(jq -e '.schema_version == "1.0.0" and (.clients | length == 30) and all(.clients[]; .loyalty.member_since and (.loyalty.points >= 0) and .loyalty.tier)' "$DATA_DIR/clients.json" >/dev/null; echo $?)"
  require_condition "vendors dataset has schema version 1.0.0 and exactly 8 active vendors" "$(jq -e '.schema_version == "1.0.0" and (.vendors | length == 8) and all(.vendors[]; .status == "active" and (.catalog | length > 0) and (.sales | length > 0))' "$DATA_DIR/vendors.json" >/dev/null; echo $?)"
else
  fail "jq and all JSON datasets are available for structured validation"
fi

if [[ -f "$DATA_DIR/tickets.csv" ]]; then
  ticket_rows=$(( $(wc -l <"$DATA_DIR/tickets.csv") - 1 ))
  [[ "$ticket_rows" -eq 200 ]] && pass "tickets dataset has exactly 200 data rows" || fail "tickets dataset has exactly 200 data rows"
  unique_lines="$(tail -n +2 "$DATA_DIR/tickets.csv" | cut -d, -f1 | sort -u | wc -l)"
  [[ "$unique_lines" -eq 200 ]] && pass "ticket line identifiers are unique" || fail "ticket line identifiers are unique"
  if tail -n +2 "$DATA_DIR/tickets.csv" | awk -F, '$3 !~ /^MAG(00[1-9]|01[0-2])$/ {exit 1}'; then
    pass "ticket rows reference the 12 stores"
  else
    fail "ticket rows reference the 12 stores"
  fi
else
  fail "tickets dataset is available for CSV validation"
fi

EXPECTED_ACCOUNTS="$($SHELL -c 'printf "%s\n" f.leclerc n.roussel a.perrot resp.mag{001..012} logistique.entrepot svc_deploy svc_caisse agence.web client_test vendeur_test' 2>/dev/null || true)"
if [[ -f "$DATA_DIR/accounts.csv" ]]; then
  actual_accounts="$(tail -n +2 "$DATA_DIR/accounts.csv" | cut -d, -f1 | sort)"
  expected_accounts="$(printf '%s\n' "$EXPECTED_ACCOUNTS" | sort)"
  if [[ "$(tail -n +2 "$DATA_DIR/accounts.csv" | wc -l)" -eq 21 ]] && [[ "$actual_accounts" == "$expected_accounts" ]]; then
    pass "accounts dataset contains exactly the 21 CDC accounts"
  else
    fail "accounts dataset contains exactly the 21 CDC accounts"
  fi
else
  fail "accounts dataset is available for exact validation"
fi

if [[ -d "$DATA_DIR/exports" ]]; then
  export_count="$(find "$DATA_DIR/exports" -maxdepth 1 -type f -name 'export-comptable-????-??-??.csv' | wc -l)"
  [[ "$export_count" -ge 2 ]] && pass "at least two dated accounting exports are versioned" || fail "at least two dated accounting exports are versioned"
else
  fail "dated accounting exports directory exists"
fi

if [[ -f "$E15_COMPOSE" && -f "$E16_COMPOSE" ]]; then
  require_condition "E15 uses pinned Zabbix server and web images" "$(grep -q 'zabbix/zabbix-server-mysql:alpine-7.0.27' "$E15_COMPOSE" && grep -q 'zabbix/zabbix-web-nginx-mysql:alpine-7.0.27' "$E15_COMPOSE" && ! grep -q ':latest' "$E15_COMPOSE"; echo $?)"
  require_condition "E16 uses a pinned nginx image" "$(grep -Eq 'image: nginx:[^[:space:]]+' "$E16_COMPOSE" && ! grep -q ':latest' "$E16_COMPOSE"; echo $?)"
  require_condition "E15 joins only net-admin" "$(grep -q 'net-admin' "$E15_COMPOSE" && ! grep -Eq 'net-(dmz|srv|data|users|spec)|mv-[abc]-' "$E15_COMPOSE"; echo $?)"
  require_condition "E16 joins only net-srv" "$(grep -q 'net-srv' "$E16_COMPOSE" && ! grep -Eq 'net-(dmz|admin|data|users|spec)|mv-[abc]-' "$E16_COMPOSE"; echo $?)"
  require_condition "E15 and E16 publish no host ports" "$(! grep -q '^[[:space:]]*ports:' "$E15_COMPOSE" "$E16_COMPOSE"; echo $?)"
  require_condition "E15 and E16 declare healthchecks" "$(grep -q 'healthcheck:' "$E15_COMPOSE" && grep -q 'healthcheck:' "$E16_COMPOSE"; echo $?)"
  require_condition "E15 persists its MariaDB database" "$(grep -q 'e15-zabbix-mysql:/var/lib/mysql' "$E15_COMPOSE"; echo $?)"
  require_condition "E15 and E16 use restart, pull policy and log rotation" "$(for compose in "$E15_COMPOSE" "$E16_COMPOSE"; do grep -q 'restart: unless-stopped' "$compose" && grep -q 'pull_policy: never' "$compose" && grep -q 'max-size: "10m"' "$compose" && grep -q 'max-file: "3"' "$compose" || exit 1; done; echo $?)"
  memory_total="$(awk '/mem_limit:/ {value=$2; gsub(/[^0-9]/, "", value); total += value} END {print total + 0}' "$E15_COMPOSE" "$E16_COMPOSE")"
  [[ "$memory_total" -eq 1152 ]] && pass "E15 and E16 total memory is exactly 1152 MiB" || fail "E15 and E16 total memory is exactly 1152 MiB"
  require_condition "each E15/E16 container stays at or below 1024 MiB" "$(awk '/mem_limit:/ {value=$2; gsub(/[^0-9]/, "", value); value += 0; if (value > 1024) exit 1; found++} END {if (found != 4) exit 1}' "$E15_COMPOSE" "$E16_COMPOSE"; echo $?)"
  require_condition "healthy services contain no flag, CVE or vulnerable primitive" "$(! grep -Eiq 'FLAG\{|mv_flag_value|CVE-|privileged:|network_mode:[[:space:]]*host|docker.sock' "$E15_COMPOSE" "$E16_COMPOSE" "$E15_INSTALL" "$E16_INSTALL"; echo $?)"
else
  fail "E15 and E16 Compose files are available for policy validation"
fi

if [[ -f "$DEPLOY_DIR/config/images.lock" && -f "$E15_COMPOSE" ]]; then
  missing_e15_image=0
  while read -r e15_image; do
    grep -Fxq "$e15_image" "$DEPLOY_DIR/config/images.lock" || missing_e15_image=1
  done < <(awk '/^[[:space:]]*image:/ {print $2}' "$E15_COMPOSE")
  [[ "$missing_e15_image" -eq 0 ]] && pass "E15 images are pinned in images.lock" || fail "E15 images are pinned in images.lock"
else
  fail "E15 image inventory can be validated"
fi

for script in "${BASH_FILES[@]}"; do
  [[ -f "$script" ]] || continue
  if grep -Eiq 'apt-get|apt[[:space:]]+install|apk[[:space:]]+add|yum[[:space:]]+install|dnf[[:space:]]+install|pip[3]?[[:space:]]+install|npm[[:space:]]+install|git[[:space:]]+clone|docker[[:space:]]+pull|suricata-update' "$script"; then
    fail "no installer or download command in ${script#"$REPO_ROOT"/}"
  else
    pass "no installer or download command in ${script#"$REPO_ROOT"/}"
  fi
done

for workflow in "$SEED_ALL" "$ORDER_FLOW" "$SEARCH_FLOW" "$SALES_FLOW" "$SCHEDULES"; do
  if [[ -f "$workflow" ]] && grep -q '^WORKFLOW_VERSION="1.0.0"$' "$workflow"; then
    pass "workflow schema is versioned: ${workflow#"$REPO_ROOT"/}"
  else
    fail "workflow schema is versioned: ${workflow#"$REPO_ROOT"/}"
  fi
done

if [[ -f "$ORDER_FLOW" && -f "$SEARCH_FLOW" && -f "$SALES_FLOW" ]]; then
  mock_dir="$(mktemp -d)"
  trap 'rm -rf "$mock_dir"' EXIT
  mkdir -p "$mock_dir/logs"
  cat >"$mock_dir/docker" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MOCK_DOCKER_LOG"
if [[ "$*" == *"sort=sku"* ]]; then
  exit 22
elif [[ "$*" == *"SELECT sku FROM products"* ]]; then
  printf 'MV-P001\nMV-P002\nMV-P003\n'
elif [[ "$*" == *"_search?q=sku"* ]]; then
  printf '{"hits":{"hits":[{"_source":{"sku":"MV-P001"}},{"_source":{"sku":"MV-P002"}},{"_source":{"sku":"MV-P003"}}]}}\n'
fi
MOCK
  chmod +x "$mock_dir/docker"
  export PATH="$mock_dir:$PATH"
  export MOCK_DOCKER_LOG="$mock_dir/docker.calls"
  export MV_BUSINESS_LOG_DIR="$mock_dir/logs"
  export MV_BUSINESS_DATA_DIR="$DATA_DIR"
  export MV_E12_DB_PASSWORD="test-only-password"

  if "$SEED_ALL" >/dev/null 2>&1 \
    && grep -q 'search-srv01' "$MOCK_DOCKER_LOG" \
    && grep -q 'catalog-data01' "$MOCK_DOCKER_LOG" \
    && grep -q 'clients-data01-mongo' "$MOCK_DOCKER_LOG" \
    && grep -q 'pos-consol-shops01-db' "$MOCK_DOCKER_LOG" \
    && grep -q 'files-srv01' "$MOCK_DOCKER_LOG" \
    && grep -q 'crm-srv01' "$MOCK_DOCKER_LOG"; then
    pass "seed-all imports versioned datasets into every business target"
  else
    fail "seed-all imports versioned datasets into every business target"
  fi

  : >"$MOCK_DOCKER_LOG"
  if "$ORDER_FLOW" >/dev/null 2>&1 \
    && grep -q 'CMD-R03-20260915-001' "$MOCK_DOCKER_LOG" \
    && grep -q 'PREP-R03-20260915-001' "$MOCK_DOCKER_LOG" \
    && grep -q 'shop-dmz01' "$MOCK_DOCKER_LOG"; then
    pass "R-03 writes deterministic order and preparation IDs"
  else
    fail "R-03 writes deterministic order and preparation IDs"
  fi

  : >"$MOCK_DOCKER_LOG"
  if "$SEARCH_FLOW" >/dev/null 2>&1 \
    && grep -q 'catalog-data01' "$MOCK_DOCKER_LOG" \
    && grep -q 'search-srv01' "$MOCK_DOCKER_LOG"; then
    pass "R-04 compares E7 search references with E10 catalog references"
  else
    fail "R-04 compares E7 search references with E10 catalog references"
  fi

  : >"$MOCK_DOCKER_LOG"
  if "$SALES_FLOW" >/dev/null 2>&1 \
    && grep -q 'LOT-R05-20260915-MAG001' "$MOCK_DOCKER_LOG" \
    && grep -q 'pos-consol-shops01-db' "$MOCK_DOCKER_LOG" \
    && grep -q 'files-srv01' "$MOCK_DOCKER_LOG"; then
    pass "R-05 loads a deterministic sales batch into E12 and exports it to E9"
  else
    fail "R-05 loads a deterministic sales batch into E12 and exports it to E9"
  fi

  log_count="$(find "$mock_dir/logs" -type f -name '*.log' | wc -l)"
  [[ "$log_count" -eq 3 ]] && pass "all three demos create timestamped audit logs" || fail "all three demos create timestamped audit logs"
else
  fail "R-03/R-04/R-05 scripts are available for mocked execution"
fi

printf '[MaisonVerte] %d checks run, %d failed\n' "$CHECKS" "$FAILURES"
if [[ "$FAILURES" -gt 0 ]]; then exit 1; fi
exit 0
