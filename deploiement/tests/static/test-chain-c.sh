#!/usr/bin/env bash
# Static test for Task 6 (Chain C E6-E9-E13).
# Read-only and offline: never starts containers or executes installers.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"
SRV_DIR="$DEPLOY_DIR/20-srv"
SHOPS_DIR="$DEPLOY_DIR/60-shops"

INSTALL_E6="$SRV_DIR/install-e6-backoffice.sh"
INSTALL_E9="$SRV_DIR/install-e9-marketing-files.sh"
INSTALL_E13="$SHOPS_DIR/install-e13-wms.sh"
INSTALL_SCRIPTS=("$INSTALL_E6" "$INSTALL_E9" "$INSTALL_E13")

E6_DIR="$SRV_DIR/services/e6"
E9_DIR="$SRV_DIR/services/e9"
E13_DIR="$SHOPS_DIR/services/e13"
E6_COMPOSE="$E6_DIR/compose.yaml"
E9_COMPOSE="$E9_DIR/compose.yaml"
E13_COMPOSE="$E13_DIR/compose.yaml"
COMPOSE_FILES=("$E6_COMPOSE" "$E9_COMPOSE" "$E13_COMPOSE")
E6_CLUE="$E6_DIR/content/chain-c-pivot.txt"
E9_SMB_CONF="$E9_DIR/smb.conf"
E9_PROCEDURE="$E9_DIR/content/share/procedure-wms.txt"
E13_PROFILE="$E13_DIR/content/wms-profile.txt"

CHECKS=0
FAILURES=0
pass() { CHECKS=$((CHECKS + 1)); printf '[MaisonVerte] PASS: %s\n' "$1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; }
require_condition() { if [[ "$2" -eq 0 ]]; then pass "$1"; else fail "$1"; fi; }
rel() { printf '%s\n' "${1#"$REPO_ROOT"/}"; }
code_lines() { grep -v -E '^[[:space:]]*#' "$1" | grep -viE 'never|jamais|absence'; }

required_files=(
  "${INSTALL_SCRIPTS[@]}"
  "${COMPOSE_FILES[@]}"
  "$E6_CLUE" "$E9_SMB_CONF" "$E9_PROCEDURE" "$E13_PROFILE"
  "$E9_DIR/content/share/exports/export-comptable-2026-09-15.csv"
  "$E9_DIR/content/share/visuels/catalogue-automne.txt"
  "$E9_DIR/content/share/campagnes/campagne-automne-2026.txt"
)
for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then pass "file exists: $(rel "$f")"; else fail "file exists: $(rel "$f")"; fi
done

for f in "${INSTALL_SCRIPTS[@]}"; do
  if [[ -f "$f" ]] && bash -n "$f" 2>/dev/null; then pass "bash -n succeeds: $(rel "$f")"; else fail "bash -n succeeds: $(rel "$f")"; fi
done

for f in "${COMPOSE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  require_condition "$(rel "$f") sets pull_policy: never" "$(grep -q 'pull_policy: never' "$f"; echo $?)"
  require_condition "$(rel "$f") uses restart: unless-stopped" "$(grep -q 'restart: unless-stopped' "$f"; echo $?)"
  require_condition "$(rel "$f") rotates logs (10m x 3)" "$(grep -q 'max-size: "10m"' "$f" && grep -q 'max-file: "3"' "$f"; echo $?)"
  require_condition "$(rel "$f") declares a healthcheck" "$(grep -q 'healthcheck:' "$f"; echo $?)"
  require_condition "$(rel "$f") has no host ports" "$(grep -Eq '^[[:space:]]*ports:' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use latest" "$(grep -Eq ':latest\b' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use privileged" "$(grep -q 'privileged: true' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not use host networking" "$(grep -q 'network_mode: host' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") does not mount docker.sock" "$(grep -q 'docker.sock' "$f"; echo $((1 - $?)))"
  require_condition "$(rel "$f") defines a memory limit" "$(grep -q 'mem_limit:' "$f"; echo $?)"
done

require_condition "E6 pins OFBiz 18.12.10" "$(grep -q 'vulhub/ofbiz:18.12.10' "$E6_COMPOSE"; echo $?)"
require_condition "E6 container is backoffice-srv01" "$(grep -q 'container_name: backoffice-srv01' "$E6_COMPOSE"; echo $?)"
require_condition "E6 runs OFBiz without the image JDWP agent" "$(grep -q 'command:.*java.*-jar.*\./build/libs/ofbiz.jar' "$E6_COMPOSE" && ! grep -R -q 'agentlib:jdwp' "$E6_DIR"; echo $?)"
require_condition "E6 never exposes or mentions port 5005" "$(grep -R -q '5005' "$E6_DIR"; echo $((1 - $?)))"
require_condition "E6 exposes only HTTPS 8443 internally" "$(grep -q '"8443"' "$E6_COMPOSE" && [[ $(grep -cE '^[[:space:]]+- "[0-9]+"' "$E6_COMPOSE") -eq 1 ]]; echo $?)"
require_condition "E6 joins exactly mv-c-edge and mv-c-core" "$(grep -q 'mv-c-edge' "$E6_COMPOSE" && grep -q 'mv-c-core' "$E6_COMPOSE" && ! grep -Eq 'mv-c-spec|net-srv|net-dmz' "$E6_COMPOSE"; echo $?)"
require_condition "E6 persists runtime data and flag" "$(grep -q 'e6-ofbiz-runtime:/usr/src/apache-ofbiz/runtime' "$E6_COMPOSE" && grep -q 'state/services/e6/flag.txt:/opt/maisonverte/flag.txt:ro' "$E6_COMPOSE"; echo $?)"
require_condition "E6 first clue points only to E9" "$(grep -q 'files-srv01' "$E6_CLUE" && grep -q 'myshare' "$E6_CLUE" && ! grep -Eq 'wms-shops01|E13|8080' "$E6_CLUE"; echo $?)"
require_condition "install-e6 resolves only the E6 flag" "$(grep -q 'mv_flag_value E6' "$INSTALL_E6" && ! grep -Eq 'mv_flag_value E(9|13)' "$INSTALL_E6"; echo $?)"

require_condition "E9 pins Samba 4.6.3" "$(grep -q 'vulhub/samba:4.6.3' "$E9_COMPOSE"; echo $?)"
require_condition "E9 container is files-srv01" "$(grep -q 'container_name: files-srv01' "$E9_COMPOSE"; echo $?)"
require_condition "E9 exposes only SMB 445 internally" "$(grep -q '"445"' "$E9_COMPOSE" && [[ $(grep -cE '^[[:space:]]+- "[0-9]+"' "$E9_COMPOSE") -eq 1 ]]; echo $?)"
require_condition "E9 Samba daemon listens only on TCP 445" "$(grep -q 'smb ports = 445' "$E9_SMB_CONF"; echo $?)"
require_condition "E9 never exposes or mentions bind-shell port 6699" "$(grep -R -q '6699' "$E9_DIR"; echo $((1 - $?)))"
require_condition "E9 joins exactly mv-c-core and mv-c-spec" "$(grep -q 'mv-c-core' "$E9_COMPOSE" && grep -q 'mv-c-spec' "$E9_COMPOSE" && ! grep -Eq 'mv-c-edge|net-srv|net-spec' "$E9_COMPOSE"; echo $?)"
require_condition "E9 keeps anonymous /home/share writable and executable" "$(grep -q 'path = /home/share' "$E9_SMB_CONF" && grep -q 'guest ok = yes' "$E9_SMB_CONF" && grep -q 'guest only = yes' "$E9_SMB_CONF" && grep -q 'read only = no' "$E9_SMB_CONF" && grep -q 'acl allow execute always = yes' "$E9_SMB_CONF"; echo $?)"
require_condition "E9 persists the writable share and keeps flag outside it" "$(grep -q 'state/services/e9/share:/home/share' "$E9_COMPOSE" && grep -q 'state/services/e9/flag.txt:/opt/maisonverte/flag.txt:ro' "$E9_COMPOSE" && ! grep -q 'flag.txt:/home/share' "$E9_COMPOSE"; echo $?)"
require_condition "E9 public share contains no flag artifact" "$({ ! find "$E9_DIR/content/share" -type f -iname '*flag*' -print -quit 2>/dev/null | grep -q .; } && ! grep -R -q 'FLAG{' "$E9_DIR/content/share" 2>/dev/null; echo $?)"
require_condition "E9 WMS procedure points only to E13" "$(grep -q 'wms-shops01:8080' "$E9_PROCEDURE" && ! grep -Eq 'backoffice-srv01|files-srv01|E6' "$E9_PROCEDURE"; echo $?)"
require_condition "install-e9 resolves only E9 and stages persistent share content" "$(grep -q 'mv_flag_value E9' "$INSTALL_E9" && grep -q 'content/share' "$INSTALL_E9" && grep -q 'SERVICE_STATE/share' "$INSTALL_E9" && ! grep -Eq 'mv_flag_value E(6|13)' "$INSTALL_E9"; echo $?)"

require_condition "E13 pins Struts2 2.3.30" "$(grep -q 'vulhub/struts2:2.3.30' "$E13_COMPOSE"; echo $?)"
require_condition "E13 container is wms-shops01" "$(grep -q 'container_name: wms-shops01' "$E13_COMPOSE"; echo $?)"
require_condition "E13 exposes only HTTP 8080 internally" "$(grep -q '"8080"' "$E13_COMPOSE" && [[ $(grep -cE '^[[:space:]]+- "[0-9]+"' "$E13_COMPOSE") -eq 1 ]]; echo $?)"
require_condition "E13 joins only mv-c-spec" "$(grep -q 'mv-c-spec' "$E13_COMPOSE" && ! grep -Eq 'mv-c-edge|mv-c-core|net-spec' "$E13_COMPOSE"; echo $?)"
require_condition "E13 preserves the vulnerable multipart app command" "$(grep -q 'multipart/form-data' "$E13_PROFILE" && ! grep -q '^[[:space:]]*command:' "$E13_COMPOSE"; echo $?)"
require_condition "E13 never mounts source or Maven cache" "$(grep -Eq '/usr/src|/root/\.m2' "$E13_COMPOSE"; echo $((1 - $?)))"
require_condition "E13 persists its final flag outside decorative content" "$(grep -q 'state/services/e13/flag.txt:/opt/maisonverte/flag.txt:ro' "$E13_COMPOSE" && ! grep -R -q 'FLAG{' "$E13_DIR/content"; echo $?)"
require_condition "install-e13 resolves only the E13 flag" "$(grep -q 'mv_flag_value E13' "$INSTALL_E13" && ! grep -Eq 'mv_flag_value E(6|9)([^0-9]|$)' "$INSTALL_E13"; echo $?)"

mem_total="$(awk '/mem_limit:/ {value=$2; gsub(/[^0-9]/, "", value); total += value} END {print total + 0}' "${COMPOSE_FILES[@]}" 2>/dev/null)"
if [[ "$mem_total" -gt 0 && "$mem_total" -le 2304 ]]; then
  pass "chain C memory total is explicit and at most 2304 MiB ($mem_total MiB)"
else
  fail "chain C memory total is explicit and at most 2304 MiB (found $mem_total MiB)"
fi

for f in "${COMPOSE_FILES[@]}" "${INSTALL_SCRIPTS[@]}"; do
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
