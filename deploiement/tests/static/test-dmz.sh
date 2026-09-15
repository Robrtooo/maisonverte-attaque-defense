#!/usr/bin/env bash
# Static test for Task 3 (Services DMZ E2-E5).
#
# This test is read-only and offline: it inspects the four install
# scripts, their Compose projects, nginx/Tomcat configuration and seed
# script as text (bash -n, grep). It never invokes `docker`, `curl` or any
# network/mutating command, and never starts a container. Compose
# rendering itself (`docker compose config --quiet`) is validated
# separately per the Task 3 brief's Step 4.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"
DMZ_DIR="$DEPLOY_DIR/10-dmz"

INSTALL_E2="$DMZ_DIR/install-e2-reverse-proxy.sh"
INSTALL_E3="$DMZ_DIR/install-e3-wordpress.sh"
INSTALL_E4="$DMZ_DIR/install-e4-mobile-api.sh"
INSTALL_E5="$DMZ_DIR/install-e5-vendor-portal.sh"
INSTALL_SCRIPTS=("$INSTALL_E2" "$INSTALL_E3" "$INSTALL_E4" "$INSTALL_E5")

E2_DIR="$DMZ_DIR/services/e2"
E3_DIR="$DMZ_DIR/services/e3"
E4_DIR="$DMZ_DIR/services/e4"
E5_DIR="$DMZ_DIR/services/e5"

E2_COMPOSE="$E2_DIR/compose.yaml"
E3_COMPOSE="$E3_DIR/compose.yaml"
E4_COMPOSE="$E4_DIR/compose.yaml"
E5_COMPOSE="$E5_DIR/compose.yaml"
COMPOSE_FILES=("$E2_COMPOSE" "$E3_COMPOSE" "$E4_COMPOSE" "$E5_COMPOSE")

E3_SEED="$E3_DIR/seed-wordpress.sh"
E5_DOCKERFILE="$E5_DIR/Dockerfile"
E2_CACHE_CONF="$E2_DIR/conf.d/cache.conf"
E2_SHOP_CONF="$E2_DIR/conf.d/shop.conf"
E2_API_CONF="$E2_DIR/conf.d/api.conf"
E2_VENDOR_CONF="$E2_DIR/conf.d/vendors.conf"

CHECKS=0
FAILURES=0

pass() {
  CHECKS=$((CHECKS + 1))
  printf '[MaisonVerte] PASS: %s\n' "$1"
}

fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  printf '[MaisonVerte] FAIL: %s\n' "$1" >&2
}

require_condition() {
  # require_condition <description> <0-or-nonzero-exit-code>
  if [[ "$2" -eq 0 ]]; then
    pass "$1"
  else
    fail "$1"
  fi
}

rel() {
  printf '%s\n' "${1#"$REPO_ROOT"/}"
}

# code_lines <file>
# Strip full-comment lines and any prose line documenting an absence
# ("never"/"jamais") so forbidden-command checks grep real invocations,
# not documentation about their absence. Mirrors test-infra.sh.
code_lines() {
  grep -v -E '^[[:space:]]*#' "$1" | grep -viE 'never|jamais'
}

# --- 0. Required files exist ------------------------------------------------

REQUIRED_FILES=(
  "$INSTALL_E2" "$INSTALL_E3" "$INSTALL_E4" "$INSTALL_E5"
  "$E2_COMPOSE" "$E2_DIR/nginx.conf"
  "$E3_COMPOSE" "$E3_SEED"
  "$E4_COMPOSE" "$E4_DIR/nginx.conf"
  "$E5_COMPOSE" "$E5_DOCKERFILE"
)
for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    pass "file exists: $(rel "$f")"
  else
    fail "file exists: $(rel "$f")"
  fi
done

# --- 1. Bash syntax is valid for every script -------------------------------

BASH_SCRIPTS=("${INSTALL_SCRIPTS[@]}" "$E3_SEED")
for f in "${BASH_SCRIPTS[@]}"; do
  if [[ -f "$f" ]]; then
    if bash -n "$f" 2>/dev/null; then
      pass "bash -n succeeds: $(rel "$f")"
    else
      fail "bash -n succeeds: $(rel "$f")"
    fi
  else
    fail "bash -n succeeds: $(rel "$f") (file missing)"
  fi
done

# --- 2. No package manager / download / docker-pull commands ---------------

FORBIDDEN_PATTERNS=(
  'apt-get' 'apt[[:space:]]+install' 'apk[[:space:]]+add'
  'yum[[:space:]]+install' 'dnf[[:space:]]+install'
  'pip[3]?[[:space:]]+install' 'npm[[:space:]]+install'
  'git[[:space:]]+clone' 'wget[[:space:]]' 'curl[[:space:]]+-O'
  'curl[[:space:]]+-o[[:space:]]' 'curl[[:space:]]+--output'
  'docker[[:space:]]+pull' 'suricata-update'
)

for f in "${BASH_SCRIPTS[@]}"; do
  [[ -f "$f" ]] || continue
  bad=0
  for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if grep -Eq "$pattern" <(code_lines "$f"); then
      bad=1
      fail "no package-manager/download command ($pattern) in $(rel "$f")"
    fi
  done
  if [[ "$bad" -eq 0 ]]; then
    pass "no package-manager/download command in $(rel "$f")"
  fi
done

# --- 3. Container names --------------------------------------------------

declare -A CONTAINER_NAMES=(
  ["$E2_COMPOSE"]="cache-dmz01"
  ["$E3_COMPOSE"]="shop-dmz01"
  ["$E4_COMPOSE"]="mobile-dmz01"
  ["$E5_COMPOSE"]="market-dmz01"
)
for f in "${COMPOSE_FILES[@]}"; do
  [[ -f "$f" ]] || { fail "container_name check (file missing): $(rel "$f")"; continue; }
  name="${CONTAINER_NAMES[$f]}"
  require_condition "$(rel "$f") sets container_name: $name" \
    "$(grep -q "container_name: $name" "$f"; echo $?)"
done

# --- 4. Networks per service -------------------------------------------------

if [[ -f "$E2_COMPOSE" ]]; then
  require_condition "E2 compose joins net-dmz" "$(grep -q 'net-dmz' "$E2_COMPOSE"; echo $?)"
  require_condition "E2 compose joins mv-a-edge" "$(grep -q 'mv-a-edge' "$E2_COMPOSE"; echo $?)"
  require_condition "E2 compose does NOT join mv-b-edge/mv-c-edge" \
    "$(grep -Eq 'mv-b-edge|mv-c-edge' "$E2_COMPOSE"; echo $((1 - $?)))"
fi

if [[ -f "$E3_COMPOSE" ]]; then
  require_condition "E3 compose joins net-dmz" "$(grep -q 'net-dmz' "$E3_COMPOSE"; echo $?)"
  require_condition "E3 compose joins mv-c-edge" "$(grep -q 'mv-c-edge' "$E3_COMPOSE"; echo $?)"
  require_condition "E3 compose declares private backend network mv-e3-db" \
    "$(grep -q 'mv-e3-db' "$E3_COMPOSE"; echo $?)"
  require_condition "E3 compose does NOT mark mv-e3-db external" \
    "$(awk '/^[[:space:]]*mv-e3-db:/{f=1;next} f && /external: *true/{print;exit} f && /^[^[:space:]]/{exit}' "$E3_COMPOSE" | grep -q .; echo $((1 - $?)))"
fi

if [[ -f "$E4_COMPOSE" ]]; then
  require_condition "E4 compose joins net-dmz" "$(grep -q 'net-dmz' "$E4_COMPOSE"; echo $?)"
  require_condition "E4 compose joins ONLY net-dmz (no micro-segment)" \
    "$(grep -Eq 'mv-a-edge|mv-b-edge|mv-c-edge' "$E4_COMPOSE"; echo $((1 - $?)))"
fi

if [[ -f "$E5_COMPOSE" ]]; then
  require_condition "E5 compose joins net-dmz" "$(grep -q 'net-dmz' "$E5_COMPOSE"; echo $?)"
  require_condition "E5 compose joins mv-b-edge" "$(grep -q 'mv-b-edge' "$E5_COMPOSE"; echo $?)"
  require_condition "E5 compose does NOT join mv-a-edge/mv-c-edge" \
    "$(grep -Eq 'mv-a-edge|mv-c-edge' "$E5_COMPOSE"; echo $((1 - $?)))"
fi

# --- 5. Single public bind: 192.168.10.50:443:443 on E2 only ---------------

total_bind=0
for f in "${COMPOSE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  count="$(grep -c -- '192\.168\.10\.50:443:443' "$f" || true)"
  total_bind=$((total_bind + count))
  if [[ "$f" != "$E2_COMPOSE" && "$count" -gt 0 ]]; then
    fail "$(rel "$f") does NOT publish 192.168.10.50:443:443 (only E2 may)"
  fi
done
require_condition "exactly one 192.168.10.50:443:443 bind across all four Compose files" \
  "$([[ "$total_bind" -eq 1 ]]; echo $?)"

total_published_ports="$(awk '
  /^[[:space:]]+ports:[[:space:]]*$/ { in_ports=1; next }
  in_ports && /^[[:space:]]+-[[:space:]]/ { count++; next }
  in_ports && !/^[[:space:]]*$/ { in_ports=0 }
  END { print count + 0 }
' "${COMPOSE_FILES[@]}")"
require_condition "exactly one published port entry exists across all four Compose files" \
  "$([[ "$total_published_ports" -eq 1 ]]; echo $?)"

for f in "$E3_COMPOSE" "$E4_COMPOSE" "$E5_COMPOSE"; do
  [[ -f "$f" ]] || { fail "no ports: block (file missing): $(rel "$f")"; continue; }
  require_condition "$(rel "$f") has no ports: entry at all" \
    "$(grep -Eq '^[[:space:]]*ports:' "$f"; echo $((1 - $?)))"
done

# --- 6. TLS material referenced by E2 ---------------------------------------

if [[ -f "$E2_COMPOSE" ]]; then
  require_condition "E2 compose mounts state/tls/maisonverte.crt" \
    "$(grep -q 'state/tls/maisonverte.crt' "$E2_COMPOSE"; echo $?)"
  require_condition "E2 compose mounts state/tls/maisonverte.key" \
    "$(grep -q 'state/tls/maisonverte.key' "$E2_COMPOSE"; echo $?)"
fi
if [[ -f "$E2_DIR/nginx.conf" ]]; then
  require_condition "E2 nginx.conf sets ssl_certificate" \
    "$(grep -q 'ssl_certificate ' "$E2_DIR/nginx.conf"; echo $?)"
  require_condition "E2 nginx.conf sets ssl_certificate_key" \
    "$(grep -q 'ssl_certificate_key' "$E2_DIR/nginx.conf"; echo $?)"
fi

# --- 7. Four public vhosts on E2, preserving $http_host ---------------------

if [[ -d "$E2_DIR/conf.d" ]]; then
  for host in cache.maisonverte.fr shop.maisonverte.fr api.maisonverte.fr vendeurs.maisonverte.fr; do
    require_condition "E2 conf.d defines vhost: $host" \
      "$(grep -rq -- "$host" "$E2_DIR/conf.d"; echo $?)"
  done
  require_condition "E2 conf.d preserves \$http_host toward proxied backends" \
    "$(grep -rq 'proxy_set_header Host \$http_host' "$E2_DIR/conf.d"; echo $?)"
  require_condition "E2 conf.d proxies to shop-dmz01 (E3)" \
    "$(grep -rq 'shop-dmz01' "$E2_DIR/conf.d"; echo $?)"
  require_condition "E2 conf.d proxies to mobile-dmz01 (E4)" \
    "$(grep -rq 'mobile-dmz01' "$E2_DIR/conf.d"; echo $?)"
  require_condition "E2 conf.d proxies to market-dmz01 (E5)" \
    "$(grep -rq 'market-dmz01' "$E2_DIR/conf.d"; echo $?)"

  declare -A PROXY_CONFIGS=(
    [E3]="$E2_SHOP_CONF"
    [E4]="$E2_API_CONF"
    [E5]="$E2_VENDOR_CONF"
  )
  for ref in E3 E4 E5; do
    require_condition "E2 preserves raw Host independently for $ref" \
      "$(grep -q 'proxy_set_header Host \$http_host' "${PROXY_CONFIGS[$ref]}"; echo $?)"
  done

  poc_host='target(any -froot@localhost -be ${run{/bin/true}} null)'
  require_condition "E2 routes a PoC-shaped non-DNS Host by shop TLS SNI and preserves it" \
    "$([[ "$poc_host" != "shop.maisonverte.fr" ]] \
      && grep -q 'map \$ssl_server_name \$mv_sni_backend' "$E2_SHOP_CONF" \
      && grep -q 'shop\.maisonverte\.fr shop-dmz01:80' "$E2_SHOP_CONF" \
      && grep -q 'listen 443 ssl default_server' "$E2_SHOP_CONF" \
      && grep -q 'proxy_pass http://\$mv_sni_backend' "$E2_SHOP_CONF" \
      && grep -q 'proxy_set_header Host \$http_host' "$E2_SHOP_CONF"; echo $?)"
else
  fail "E2 conf.d vhost checks (directory missing)"
fi

# --- 8. E2 keeps only the Vulhub traversal variant --------------------------

if [[ -d "$E2_DIR/conf.d" ]]; then
  require_condition "E2 conf.d keeps the vulnerable /files alias (traversal)" \
    "$(grep -rq 'location /files' "$E2_DIR/conf.d" && grep -rq 'alias /home/;' "$E2_DIR/conf.d"; echo $?)"
  require_condition "E2 conf.d drops the CRLF-redirect variant (Mistake 1)" \
    "$(grep -rEq '\\\$host:\\\$server_port\\\$uri' "$E2_DIR/conf.d"; echo $((1 - $?)))"
  require_condition "E2 conf.d drops the add_header-override variant (Mistake 3)" \
    "$(grep -rq 'X-Content-Type-Options' "$E2_DIR/conf.d"; echo $((1 - $?)))"
fi

require_condition "E2 stores a search runbook outside the public webroot" \
  "$([[ -f "$E2_DIR/content/runbook/runbook.txt" ]]; echo $?)"
if [[ -f "$E2_COMPOSE" ]]; then
  sensitive_mount="/srv/maisonverte/runbook"
  sensitive_target="$sensitive_mount/runbook.txt"
  flag_target="/srv/maisonverte/flag.txt"
  direct_alias_target="$(realpath -m /home/runbook/runbook.txt)"
  traversal_alias_target="$(realpath -m /home/../srv/maisonverte/runbook/runbook.txt)"
  direct_flag_target="$(realpath -m /home/flag.txt)"
  traversal_flag_target="$(realpath -m /home/../srv/maisonverte/flag.txt)"
  require_condition "E2 sensitive mounts are outside the directly exposed /home alias" \
    "$(grep -Eq ':/home/(ops|cache)' "$E2_COMPOSE"; echo $((1 - $?)))"
  require_condition "E2 direct /files/runbook path cannot resolve to the runbook mount" \
    "$([[ "$direct_alias_target" != "$sensitive_target" ]]; echo $?)"
  require_condition "E2 intended /files../ traversal resolves to the runbook mount" \
    "$([[ "$traversal_alias_target" == "$sensitive_target" ]] \
      && grep -q ":$sensitive_mount:ro" "$E2_COMPOSE"; echo $?)"
  require_condition "E2 direct /files/flag path cannot resolve to the flag mount" \
    "$([[ "$direct_flag_target" != "$flag_target" ]]; echo $?)"
  require_condition "E2 intended /files../ traversal resolves to the flag mount" \
    "$([[ "$traversal_flag_target" == "$flag_target" ]] \
      && grep -q ":$flag_target:ro" "$E2_COMPOSE"; echo $?)"
fi
if [[ -d "$E2_DIR/conf.d" && -f "$E2_DIR/content/runbook/runbook.txt" ]]; then
  token="$(grep -oE 'X-MV-Search-Token: [A-Za-z0-9-]+' "$E2_DIR/content/runbook/runbook.txt" | head -n1 | awk '{print $2}')"
  require_condition "runbook documents a non-empty search token" \
    "$([[ -n "$token" ]]; echo $?)"
  require_condition "E2 conf.d's E7 route checks that same token" \
    "$([[ -n "$token" ]] && grep -rq -- "$token" "$E2_DIR/conf.d"; echo $?)"
  require_condition "E2 conf.d protects an internal route toward search-srv01 (E7)" \
    "$(grep -rq 'search-srv01' "$E2_DIR/conf.d"; echo $?)"
fi

# --- 9. E3: WordPress 4.6, no update, PHPMailer left vulnerable ------------

if [[ -f "$E3_COMPOSE" ]]; then
  require_condition "E3 compose pins vulhub/wordpress:4.6 (no 'latest')" \
    "$(grep -q 'vulhub/wordpress:4.6' "$E3_COMPOSE"; echo $?)"
fi
E3_FILES=("$E3_COMPOSE" "$E3_SEED")
for f in "${E3_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  require_condition "$(rel "$f") never patches/updates PHPMailer or WordPress core" \
    "$(grep -Eiq 'phpmailer|wp core update|wp-cli.*update' <(code_lines "$f"); echo $((1 - $?)))"
done
require_condition "E3 seed submits the WordPress 4.6 installer step 2" \
  "$(grep -q 'wp-admin/install.php?step=2' "$E3_SEED"; echo $?)"
for required_column in post_excerpt to_ping pinged post_content_filtered; do
  require_condition "E3 strict-MySQL seed supplies wp_posts.$required_column" \
    "$(grep -q "$required_column" "$E3_SEED"; echo $?)"
done

# --- 10. E3 MySQL backend stays private on mv-e3-db -------------------------

if [[ -f "$E3_COMPOSE" ]]; then
  mysql_block="$(awk '/^[[:space:]]{2}mysql:/{f=1} f{print} f && /^[[:space:]]{2}[a-zA-Z]/ && !/^[[:space:]]{2}mysql:/{exit}' "$E3_COMPOSE")"
  require_condition "E3 mysql service block exists" "$([[ -n "$mysql_block" ]]; echo $?)"
  require_condition "E3 mysql service joins mv-e3-db" \
    "$(grep -q 'mv-e3-db' <<<"$mysql_block"; echo $?)"
  require_condition "E3 mysql service does NOT join net-dmz" \
    "$(grep -q 'net-dmz' <<<"$mysql_block"; echo $((1 - $?)))"
  require_condition "E3 mysql service does NOT join mv-c-edge" \
    "$(grep -q 'mv-c-edge' <<<"$mysql_block"; echo $((1 - $?)))"
fi

# --- 11. E5: Tomcat 8.5.19, readonly=false (PUT-writable) preserved --------

if [[ -f "$E5_DOCKERFILE" ]]; then
  require_condition "E5 Dockerfile derives FROM vulhub/tomcat:8.5.19" \
    "$(grep -q 'FROM vulhub/tomcat:8.5.19' "$E5_DOCKERFILE"; echo $?)"
  require_condition "E5 Dockerfile inserts readonly=false inside the default servlet" \
    "$(grep -q '<servlet-name>default<\\/servlet-name>/{in_default=1}' "$E5_DOCKERFILE" \
      && grep -q 'in_default && /<load-on-startup>1/{print NR; exit}' "$E5_DOCKERFILE" \
      && grep -q 'in_default && /<\\/servlet>/{exit 1}' "$E5_DOCKERFILE" \
      && grep -q '<param-name>readonly</param-name><param-value>false</param-value>' "$E5_DOCKERFILE"; echo $?)"
fi
if [[ -f "$E5_COMPOSE" ]]; then
  require_condition "E5 compose builds locally (no pre-built vulnerable image reference beyond the Dockerfile FROM)" \
    "$(grep -q 'build:' "$E5_COMPOSE"; echo $?)"
fi
require_condition "E5 adds a themed vendor-portal landing page" \
  "$([[ -f "$E5_DIR/content/webapps/ROOT/index.html" || -f "$E5_DIR/content/webapps/ROOT/index.jsp" ]]; echo $?)"
require_condition "E5 landing page hints at Jenkins (deploy-srv01) without exposing a CVE/path" \
  "$(grep -rlq 'deploy-srv01' "$E5_DIR/content" 2>/dev/null; echo $?)"

# --- 12. E4: static JSON endpoints, no dangerous endpoint -------------------

if [[ -f "$E4_DIR/nginx.conf" ]]; then
  require_condition "E4 nginx.conf has no alias directive" \
    "$(grep -q 'alias ' "$E4_DIR/nginx.conf"; echo $((1 - $?)))"
  require_condition "E4 nginx.conf has no autoindex" \
    "$(grep -q 'autoindex on' "$E4_DIR/nginx.conf"; echo $((1 - $?)))"
  require_condition "E4 nginx.conf has no proxy_pass (static content only)" \
    "$(grep -q 'proxy_pass' "$E4_DIR/nginx.conf"; echo $((1 - $?)))"
  require_condition "E4 nginx.conf has no upload/write location" \
    "$(grep -Eq 'client_body_in_file_only|dav_methods' "$E4_DIR/nginx.conf"; echo $((1 - $?)))"
fi
for j in catalogue stocks commandes fidelite; do
  require_condition "E4 exposes $j.json" "$([[ -f "$E4_DIR/html/$j.json" ]]; echo $?)"
done
if [[ -f "$E4_COMPOSE" ]]; then
  e4_healthcheck="$(awk '/healthcheck:/{f=1} f{print} f && /retries:/{exit}' "$E4_COMPOSE")"
  require_condition "E4 healthcheck verifies the live nginx process and /health response definition" \
    "$(grep -q 'kill -0 1' <<<"$e4_healthcheck" \
      && grep -q 'location = /health' <<<"$e4_healthcheck" \
      && grep -q 'status.*ok' <<<"$e4_healthcheck"; echo $?)"
  require_condition "E4 healthcheck validates representative catalogue JSON content" \
    "$(grep -q '/usr/share/nginx/html/catalogue.json' <<<"$e4_healthcheck" \
      && grep -q 'products' <<<"$e4_healthcheck"; echo $?)"
fi

# --- 13. Flag resolution: E2/E3/E5 resolve their flag, E4 does not --------

require_condition "install-e2 resolves its flag via mv_flag_value E2" \
  "$([[ -f "$INSTALL_E2" ]] && grep -q 'mv_flag_value E2' "$INSTALL_E2"; echo $?)"
require_condition "install-e3 resolves its flag via mv_flag_value E3" \
  "$([[ -f "$INSTALL_E3" ]] && grep -q 'mv_flag_value E3' "$INSTALL_E3"; echo $?)"
require_condition "install-e5 resolves its flag via mv_flag_value E5" \
  "$([[ -f "$INSTALL_E5" ]] && grep -q 'mv_flag_value E5' "$INSTALL_E5"; echo $?)"
require_condition "install-e4 (healthy service) never resolves a flag" \
  "$([[ -f "$INSTALL_E4" ]] && grep -q 'mv_flag_value' "$INSTALL_E4"; echo $((1 - $?)))"

for f in "${COMPOSE_FILES[@]}" "$E3_SEED"; do
  [[ -f "$f" ]] || continue
  require_condition "$(rel "$f") never hardcodes a FLAG{...} literal" \
    "$(grep -q 'FLAG{' "$f"; echo $((1 - $?)))"
done

# --- 14. Global Compose constraints on all four services --------------------

for f in "${COMPOSE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  require_condition "$(rel "$f") uses restart: unless-stopped" \
    "$(grep -q 'restart: unless-stopped' "$f"; echo $?)"
  require_condition "$(rel "$f") sets pull_policy: never" \
    "$(grep -q 'pull_policy: never' "$f"; echo $?)"
  require_condition "$(rel "$f") rotates logs (10m x 3)" \
    "$(grep -q 'max-size: \"10m\"' "$f" && grep -q 'max-file: \"3\"' "$f"; echo $?)"
  require_condition "$(rel "$f") declares a healthcheck" \
    "$(grep -q 'healthcheck:' "$f"; echo $?)"
  require_condition "$(rel "$f") does not use the 'latest' tag" \
    "$(grep -Eq ':latest\b' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use privileged" \
    "$(grep -q 'privileged: true' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use network_mode: host" \
    "$(grep -q 'network_mode: host' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not mount docker.sock" \
    "$(grep -q 'docker.sock' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") defines memory limits" \
    "$(grep -q 'mem_limit:' "$f"; echo $?)"
done

require_condition "DMZ total configured memory budget stays at or below 2048 MiB" \
  "$(awk '
    /mem_limit:/ {
      value=$2
      gsub(/"/, "", value)
      if (value ~ /[mM]$/) { sub(/[mM]$/, "", value); total += value }
      else if (value ~ /[gG]$/) { sub(/[gG]$/, "", value); total += value * 1024 }
      else { invalid=1 }
    }
    END { exit (invalid || total > 2048 || total == 0) }
  ' "${COMPOSE_FILES[@]}"; echo $?)"

# --- Summary -----------------------------------------------------------------

printf '[MaisonVerte] %d checks run, %d failed\n' "$CHECKS" "$FAILURES"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
