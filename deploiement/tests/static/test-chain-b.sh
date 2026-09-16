#!/usr/bin/env bash
# Static test for Task 5 (Chaine B E14-E12-E11).
# Read-only and offline: validates scripts, Compose files and seeded content
# as text. It never starts containers and never executes deployment scripts.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"
SRV_DIR="$DEPLOY_DIR/20-srv"
SHOPS_DIR="$DEPLOY_DIR/60-shops"
DATA_DIR="$DEPLOY_DIR/30-data"

INSTALL_E14="$SRV_DIR/install-e14-jenkins.sh"
INSTALL_E12="$SHOPS_DIR/install-e12-sales-consolidation.sh"
INSTALL_E11="$DATA_DIR/install-e11-client-database.sh"
INSTALL_SCRIPTS=("$INSTALL_E14" "$INSTALL_E12" "$INSTALL_E11")

E14_DIR="$SRV_DIR/services/e14"
E12_DIR="$SHOPS_DIR/services/e12"
E11_DIR="$DATA_DIR/services/e11"
E14_COMPOSE="$E14_DIR/compose.yaml"
E12_COMPOSE="$E12_DIR/compose.yaml"
E11_COMPOSE="$E11_DIR/compose.yaml"
COMPOSE_FILES=("$E14_COMPOSE" "$E12_COMPOSE" "$E11_COMPOSE")
E14_GROOVY="$E14_DIR/init.groovy.d/01-maisonverte-security.groovy"
E12_SEED="$E12_DIR/seed-sales.sh"
E11_SEED="$E11_DIR/seed-clients.sh"
BASH_SCRIPTS=("${INSTALL_SCRIPTS[@]}" "$E12_SEED" "$E11_SEED")

CHECKS=0
FAILURES=0
pass() { CHECKS=$((CHECKS + 1)); printf '[MaisonVerte] PASS: %s\n' "$1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; }
require_condition() { if [[ "$2" -eq 0 ]]; then pass "$1"; else fail "$1"; fi; }
rel() { printf '%s\n' "${1#"$REPO_ROOT"/}"; }
code_lines() { grep -v -E '^[[:space:]]*#' "$1" | grep -viE 'never|jamais|absence'; }

required_files=(
  "$INSTALL_E14" "$INSTALL_E12" "$INSTALL_E11"
  "$E14_COMPOSE" "$E14_GROOVY" "$E14_DIR/content/chain-b-pivot.txt"
  "$E12_COMPOSE" "$E12_SEED" "$E12_DIR/content/jobs/nightly-sales.json"
  "$E11_COMPOSE" "$E11_SEED"
)
for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then pass "file exists: $(rel "$f")"; else fail "file exists: $(rel "$f")"; fi
done

for f in "${BASH_SCRIPTS[@]}"; do
  if [[ -f "$f" ]] && bash -n "$f" 2>/dev/null; then pass "bash -n succeeds: $(rel "$f")"; else fail "bash -n succeeds: $(rel "$f")"; fi
done

for f in "${COMPOSE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  require_condition "$(rel "$f") sets pull_policy: never" "$(grep -q 'pull_policy: never' "$f"; echo $?)"
  require_condition "$(rel "$f") uses restart: unless-stopped" "$(grep -q 'restart: unless-stopped' "$f"; echo $?)"
  require_condition "$(rel "$f") rotates logs (10m x 3)" "$(grep -q 'max-size: "10m"' "$f" && grep -q 'max-file: "3"' "$f"; echo $?)"
  require_condition "$(rel "$f") declares healthchecks" "$(grep -q 'healthcheck:' "$f"; echo $?)"
  require_condition "$(rel "$f") has no host ports" "$(grep -Eq '^[[:space:]]*ports:' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use latest" "$(grep -Eq ':latest\b' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use privileged" "$(grep -q 'privileged: true' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use network_mode host" "$(grep -q 'network_mode: host' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not mount docker.sock" "$(grep -q 'docker.sock' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") defines memory limits" "$(grep -q 'mem_limit:' "$f"; echo $?)"
done

require_condition "E14 pins Jenkins 2.441" "$(grep -q 'vulhub/jenkins:2.441' "$E14_COMPOSE"; echo $?)"
require_condition "E14 container is deploy-srv01" "$(grep -q 'container_name: deploy-srv01' "$E14_COMPOSE"; echo $?)"
require_condition "E14 joins mv-b-edge" "$(grep -q 'mv-b-edge' "$E14_COMPOSE"; echo $?)"
require_condition "E14 joins mv-b-core" "$(grep -q 'mv-b-core' "$E14_COMPOSE"; echo $?)"
require_condition "E14 persists Jenkins home" "$(grep -q 'e14-jenkins-home:/var/jenkins_home' "$E14_COMPOSE"; echo $?)"
require_condition "E14 runtime flag mount does not overlap read-only content mount" "$(grep -q 'state/services/e14:/run/maisonverte:ro' "$E14_COMPOSE"; echo $?)"
require_condition "E14 keeps CLI enabled" "$(grep -q 'jenkins.CLI.disabled=false' "$E14_COMPOSE"; echo $?)"
require_condition "E14 does not expose DEBUG" "$(grep -R -q 'DEBUG=1' "$E14_DIR"; echo $((1 - $?)))"
require_condition "E14 does not expose JDWP 5005" "$(grep -R -q '5005' "$E14_DIR"; echo $((1 - $?)))"
require_condition "E14 does not expose agent 50000" "$(grep -R -q '50000' "$E14_DIR"; echo $((1 - $?)))"
require_condition "E14 disables remoting agent port" "$(grep -q 'setSlaveAgentPort(-1)' "$E14_GROOVY"; echo $?)"
require_condition "E14 grants anonymous read for CVE-2024-23897 CLI file read" "$(grep -q 'AuthorizationStrategy.UNSECURED' "$E14_GROOVY"; echo $?)"
require_condition "E14 CLI-readable first pivot points only to E12" "$(grep -q 'pos-consol-shops01' "$E14_DIR/content/chain-b-pivot.txt" && ! grep -Eq 'clients-data01|mongo-express|E11' "$E14_DIR/content/chain-b-pivot.txt"; echo $?)"
require_condition "install-e14 resolves flag via mv_flag_value E14" "$(grep -q 'mv_flag_value E14' "$INSTALL_E14"; echo $?)"
require_condition "install-e14 uses runtime secret helper" "$(grep -q 'prepare-runtime-secrets.sh' "$INSTALL_E14"; echo $?)"

require_condition "E12 pins XXL-JOB admin" "$(grep -q 'vulhub/xxl-job:2.2.0-admin' "$E12_COMPOSE"; echo $?)"
require_condition "E12 pins XXL-JOB executor" "$(grep -q 'vulhub/xxl-job:2.2.0-executor' "$E12_COMPOSE"; echo $?)"
require_condition "E12 MySQL pins mysql:5.7" "$(grep -q 'mysql:5.7' "$E12_COMPOSE"; echo $?)"
require_condition "E12 executor container is pos-consol-shops01" "$(grep -q 'container_name: pos-consol-shops01$' "$E12_COMPOSE"; echo $?)"
require_condition "E12 admin container is pos-consol-shops01-admin" "$(grep -q 'container_name: pos-consol-shops01-admin' "$E12_COMPOSE"; echo $?)"
require_condition "E12 DB container is pos-consol-shops01-db" "$(grep -q 'container_name: pos-consol-shops01-db' "$E12_COMPOSE"; echo $?)"
require_condition "E12 exposes executor 9999 internally" "$(grep -q '"9999"' "$E12_COMPOSE"; echo $?)"
require_condition "E12 keeps vulnerable /run contract documented by executor image" "$(grep -q '2.2.0-executor' "$E12_COMPOSE" && grep -q 'executor' "$E12_COMPOSE"; echo $?)"
require_condition "E12 admin/executor join mv-b-core" "$(grep -q 'mv-b-core' "$E12_COMPOSE"; echo $?)"
require_condition "E12 admin/executor join mv-b-data" "$(grep -q 'mv-b-data' "$E12_COMPOSE"; echo $?)"
require_condition "E12 declares private MySQL backend mv-e12-db" "$(grep -q 'mv-e12-db' "$E12_COMPOSE"; echo $?)"
mysql_block="$(awk '/^[[:space:]]{2}mysql:/{f=1} f{print} f && /^[[:space:]]{2}admin:/{exit}' "$E12_COMPOSE")"
require_condition "E12 MySQL stays only on mv-e12-db" "$(grep -q 'mv-e12-db' <<<"$mysql_block" && ! grep -Eq 'mv-b-core|mv-b-data' <<<"$mysql_block"; echo $?)"
require_condition "E12 records only E11 Basic Auth credential as next pivot" "$(grep -q 'e11-mongo-express-credential.txt' "$E12_COMPOSE" && grep -q 'e11-mongo-express-credential.txt' "$E12_DIR/content/jobs/nightly-sales.json"; echo $?)"
require_condition "E12 seed references E11 /checkValid target" "$(grep -q '/checkValid' "$E12_SEED"; echo $?)"
require_condition "install-e12 resolves flag via mv_flag_value E12" "$(grep -q 'mv_flag_value E12' "$INSTALL_E12"; echo $?)"
require_condition "install-e12 creates E11 credential with runtime secret helper" "$(grep -q 'e11-mongo-express-password' "$INSTALL_E12" && grep -q 'prepare-runtime-secrets.sh' "$INSTALL_E12"; echo $?)"

require_condition "E11 pins mongo-express 0.53.0" "$(grep -q 'vulhub/mongo-express:0.53.0' "$E11_COMPOSE"; echo $?)"
require_condition "E11 pins MongoDB 3.4" "$(grep -q 'mongo:3.4' "$E11_COMPOSE"; echo $?)"
require_condition "E11 web container is clients-data01" "$(grep -q 'container_name: clients-data01$' "$E11_COMPOSE"; echo $?)"
require_condition "E11 MongoDB container is clients-data01-mongo" "$(grep -q 'container_name: clients-data01-mongo' "$E11_COMPOSE"; echo $?)"
require_condition "E11 web joins mv-b-data" "$(grep -q 'mv-b-data' "$E11_COMPOSE"; echo $?)"
require_condition "E11 declares private Mongo backend mv-e11-db" "$(grep -q 'mv-e11-db' "$E11_COMPOSE"; echo $?)"
mongo_block="$(awk '/^[[:space:]]{2}mongo:/{f=1} f && /^[^[:space:]]/{exit} f{print}' "$E11_COMPOSE")"
require_condition "E11 MongoDB stays off mv-b-data" "$(grep -q 'mv-e11-db' <<<"$mongo_block" && ! grep -q 'mv-b-data' <<<"$mongo_block"; echo $?)"
require_condition "E11 configures mongo-express Basic Auth via runtime env" "$(grep -q 'ME_CONFIG_BASICAUTH_USERNAME' "$E11_COMPOSE" && grep -q 'ME_CONFIG_BASICAUTH_PASSWORD' "$E11_COMPOSE"; echo $?)"
require_condition "E11 keeps mongo-express /checkValid vulnerable surface" "$(grep -q 'mongo-express:0.53.0' "$E11_COMPOSE" && grep -q '8081' "$E11_COMPOSE"; echo $?)"
require_condition "E11 MongoDB has persistent volume" "$(grep -q 'e11-mongo-data:/data/db' "$E11_COMPOSE"; echo $?)"
require_condition "E11 seed creates at least 30 clients" "$(grep -q 'i <= 30' "$E11_SEED"; echo $?)"
require_condition "E11 seed includes loyalty program" "$(grep -q 'loyalty_program' "$E11_SEED"; echo $?)"
require_condition "install-e11 resolves flag via mv_flag_value E11" "$(grep -q 'mv_flag_value E11' "$INSTALL_E11"; echo $?)"
require_condition "install-e11 uses same E11 Basic Auth runtime secrets" "$(grep -q 'e11-mongo-express-user' "$INSTALL_E11" && grep -q 'e11-mongo-express-password' "$INSTALL_E11"; echo $?)"

for f in "${COMPOSE_FILES[@]}" "${BASH_SCRIPTS[@]}" "$E14_GROOVY"; do
  [[ -f "$f" ]] || continue
  require_condition "$(rel "$f") never hardcodes a FLAG literal" "$(grep -q 'FLAG{' "$f"; echo $((1 - $?)))"
  bad=0
  for pattern in 'apt-get' 'apt[[:space:]]+install' 'apk[[:space:]]+add' 'yum[[:space:]]+install' 'dnf[[:space:]]+install' 'pip[3]?[[:space:]]+install' 'npm[[:space:]]+install' 'git[[:space:]]+clone' 'wget[[:space:]]' 'curl[[:space:]]+-O' 'curl[[:space:]]+-o[[:space:]]' 'curl[[:space:]]+--output' 'docker[[:space:]]+pull' 'suricata-update'; do
    if grep -Eq "$pattern" <(code_lines "$f"); then bad=1; fail "no package-manager/download command ($pattern) in $(rel "$f")"; fi
  done
  [[ "$bad" -eq 0 ]] && pass "no package-manager/download command in $(rel "$f")"
done

printf '[MaisonVerte] %d checks run, %d failed\n' "$CHECKS" "$FAILURES"
if [[ "$FAILURES" -gt 0 ]]; then exit 1; fi
exit 0
