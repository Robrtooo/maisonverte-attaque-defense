#!/usr/bin/env bash
# Static test for Task 2 (Reseaux, TLS, offline et frontiere OPNsense).
#
# This test is read-only and offline: it inspects the 00-infra and
# 90-orchestration scripts as text (bash -n, grep) and, for the two scripts
# that are pure stdout/refusal with no docker/network/openssl call
# (print-opnsense-plan.sh), actually executes them. It never invokes
# `docker`, `openssl`, `curl`, `ss` against a real target, never writes to
# deploiement/state/, and never calls any script that would.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"
CONFIG_DIR="$DEPLOY_DIR/config"
LIB_DIR="$DEPLOY_DIR/lib"
INFRA_DIR="$DEPLOY_DIR/00-infra"
ORCHESTRATION_DIR="$DEPLOY_DIR/90-orchestration"

PREFLIGHT="$INFRA_DIR/preflight.sh"
CREATE_NETWORKS="$INFRA_DIR/create-networks.sh"
GENERATE_TLS="$INFRA_DIR/generate-tls.sh"
IMPORT_IMAGES="$INFRA_DIR/import-offline-images.sh"
PRINT_PLAN="$INFRA_DIR/print-opnsense-plan.sh"
VERIFY_OPNSENSE="$INFRA_DIR/verify-opnsense.sh"
PREPARE_SECRETS="$INFRA_DIR/prepare-runtime-secrets.sh"
PREPARE_BUNDLE="$ORCHESTRATION_DIR/prepare-offline-bundle.sh"

INFRA_FILES=(
  "$PREFLIGHT" "$CREATE_NETWORKS" "$GENERATE_TLS" "$IMPORT_IMAGES"
  "$PRINT_PLAN" "$VERIFY_OPNSENSE" "$PREPARE_SECRETS"
)
LAB_SCRIPTS=("${INFRA_FILES[@]}" "$PREPARE_BUNDLE")

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
# Print <file> with full comment lines (trimmed content starting with '#')
# and any line documenting an absence in prose (containing "never" or
# "jamais" — e.g. a header comment or a log message saying "this script
# never calls docker pull") removed, so forbidden-command checks below
# grep actual invocations rather than documentation asserting they don't
# happen.
code_lines() {
  grep -v -E '^[[:space:]]*#' "$1" | grep -viE 'never|jamais'
}

# --- 0. Required files exist -------------------------------------------

for f in "${LAB_SCRIPTS[@]}"; do
  if [[ -f "$f" ]]; then
    pass "file exists: $(rel "$f")"
  else
    fail "file exists: $(rel "$f")"
  fi
done

# --- 1. Bash syntax is valid for every script -------------------------------

for f in "${LAB_SCRIPTS[@]}"; do
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
# ARCHITECTURE.md: "Aucun script n'utilise Internet dans le lab. Aucun
# docker pull, apt-get ou suricata-update n'est lance par un script de
# deploiement."

FORBIDDEN_PATTERNS=(
  'apt-get' 'apt[[:space:]]+install' 'apk[[:space:]]+add'
  'yum[[:space:]]+install' 'dnf[[:space:]]+install'
  'pip[3]?[[:space:]]+install' 'npm[[:space:]]+install'
  'git[[:space:]]+clone' 'wget[[:space:]]' 'curl[[:space:]]+-O'
  'curl[[:space:]]+-o[[:space:]]' 'curl[[:space:]]+--output'
  'docker[[:space:]]+pull' 'suricata-update'
)

for f in "${LAB_SCRIPTS[@]}"; do
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

# --- 3. create-networks.sh: exact 6 zones + 9 micro-segments, no private backend
#
# networks.env defines each network name behind a NET_*_NAME variable
# (e.g. NET_DMZ_NAME=net-dmz); create-networks.sh is expected to build its
# network table from those variables rather than duplicating the literal
# names, so this checks that each variable REFERENCE ("$NET_DMZ_NAME", …)
# is wired into create-networks.sh, and separately that networks.env still
# defines each variable (catches drift if Task 1's constants are renamed).

ZONE_VARS=(NET_DMZ_NAME NET_SRV_NAME NET_DATA_NAME NET_USERS_NAME NET_ADMIN_NAME NET_SHOPS_NAME)
MICROSEG_VARS=(NET_A_EDGE_NAME NET_A_CORE_NAME NET_A_DATA_NAME \
  NET_B_EDGE_NAME NET_B_CORE_NAME NET_B_DATA_NAME \
  NET_C_EDGE_NAME NET_C_CORE_NAME NET_C_SPEC_NAME)
PRIVATE_BACKENDS=("mv-e3-db" "mv-e11-db" "mv-e12-db")

if [[ -f "$CONFIG_DIR/networks.env" ]]; then
  for var in "${ZONE_VARS[@]}" "${MICROSEG_VARS[@]}"; do
    require_condition "networks.env defines: $var" \
      "$(grep -Eq "^${var}=" "$CONFIG_DIR/networks.env"; echo $?)"
  done
else
  fail "networks.env checks (file missing)"
fi

if [[ -f "$CREATE_NETWORKS" ]]; then
  for var in "${ZONE_VARS[@]}"; do
    require_condition "create-networks.sh references zone network variable: \$$var" \
      "$(grep -qF "\$$var" "$CREATE_NETWORKS"; echo $?)"
  done
  for var in "${MICROSEG_VARS[@]}"; do
    require_condition "create-networks.sh references micro-segment variable: \$$var" \
      "$(grep -qF "\$$var" "$CREATE_NETWORKS"; echo $?)"
  done
  for name in "${PRIVATE_BACKENDS[@]}"; do
    if grep -q -- "$name" <(code_lines "$CREATE_NETWORKS"); then
      fail "create-networks.sh does NOT create private backend network: $name"
    else
      pass "create-networks.sh does NOT create private backend network: $name"
    fi
  done
  require_condition "create-networks.sh only creates networks if absent (idempotent guard)" \
    "$(grep -Eq 'docker network (inspect|ls)' "$CREATE_NETWORKS"; echo $?)"
  require_condition "create-networks.sh assigns fixed subnets (--subnet)" \
    "$(grep -q -- '--subnet' "$CREATE_NETWORKS"; echo $?)"
  require_condition "create-networks.sh labels networks (--label)" \
    "$(grep -q -- '--label' "$CREATE_NETWORKS"; echo $?)"
else
  fail "create-networks.sh references all 6 zones + 9 micro-segments (file missing)"
fi

# --- 4. Single public bind: NAT plan + preflight ports ---------------------

if [[ -f "$PRINT_PLAN" ]]; then
  plan_output="$(bash "$PRINT_PLAN" 2>/dev/null)"
  nat_count="$(grep -c -- '->' <<<"$plan_output" || true)"
  require_condition "print-opnsense-plan.sh prints the NAT line exactly once" \
    "$([[ "$nat_count" -eq 1 ]]; echo $?)"
  require_condition "print-opnsense-plan.sh prints 10.85.4.10:443 -> 192.168.10.50:443" \
    "$(grep -q -- '10\.85\.4\.10:443[[:space:]]*->[[:space:]]*192\.168\.10\.50:443' <<<"$plan_output"; echo $?)"
  require_condition "print-opnsense-plan.sh prints the four public hostnames" \
    "$(grep -q 'shop\.maisonverte\.fr' <<<"$plan_output" \
      && grep -q 'api\.maisonverte\.fr' <<<"$plan_output" \
      && grep -q 'vendeurs\.maisonverte\.fr' <<<"$plan_output" \
      && grep -q 'cache\.maisonverte\.fr' <<<"$plan_output"; echo $?)"

  bash "$PRINT_PLAN" extra-argument >/tmp/mv-test-infra-plan-refusal.stderr 2>&1
  refusal_rc=$?
  require_condition "print-opnsense-plan.sh refuses arguments (non-zero exit)" \
    "$([[ "$refusal_rc" -ne 0 ]]; echo $?)"
  require_condition "print-opnsense-plan.sh logs the refusal" \
    "$(grep -qi 'refus' /tmp/mv-test-infra-plan-refusal.stderr; echo $?)"
  rm -f /tmp/mv-test-infra-plan-refusal.stderr
else
  fail "print-opnsense-plan.sh single-bind checks (file missing)"
fi

if [[ -f "$PREFLIGHT" ]]; then
  require_condition "preflight.sh checks exactly the single public bind 192.168.10.50:443" \
    "$(grep -q '192\.168\.10\.50:443' "$PREFLIGHT" && ! grep -Eq '192\.168\.10\.5[1-9]|192\.168\.1[1-9][0-9]?\.' "$PREFLIGHT"; echo $?)"
  require_condition "preflight.sh never mutates docker state (no run/rm/network create/load/save/exec)" \
    "$(grep -Eq 'docker[[:space:]]+(run|rm|network[[:space:]]+create|load|save|exec)' <(code_lines "$PREFLIGHT"); echo $((1 - $?)))"
else
  fail "preflight.sh single-bind checks (file missing)"
fi

# --- 5. import-offline-images.sh: checksum verified BEFORE docker load -----

if [[ -f "$IMPORT_IMAGES" ]]; then
  checksum_line="$(grep -n 'sha256sum' "$IMPORT_IMAGES" | head -n1 | cut -d: -f1)"
  load_line="$(grep -n 'docker load' "$IMPORT_IMAGES" | head -n1 | cut -d: -f1)"
  if [[ -n "$checksum_line" && -n "$load_line" ]]; then
    require_condition "import-offline-images.sh verifies sha256 before docker load" \
      "$([[ "$checksum_line" -lt "$load_line" ]]; echo $?)"
  else
    fail "import-offline-images.sh verifies sha256 before docker load (missing sha256sum or docker load)"
  fi
  require_condition "import-offline-images.sh never calls docker pull" \
    "$(grep -Eq 'docker[[:space:]]+pull' <(code_lines "$IMPORT_IMAGES"); echo $((1 - $?)))"
else
  fail "import-offline-images.sh checksum-before-load checks (file missing)"
fi

# --- 6. generate-tls.sh: public SAN, local openssl only, --force guard -----

if [[ -f "$GENERATE_TLS" ]]; then
  require_condition "generate-tls.sh sets subjectAltName for *.maisonverte.fr" \
    "$(grep -q 'DNS:\*\.maisonverte\.fr' "$GENERATE_TLS"; echo $?)"
  require_condition "generate-tls.sh uses local openssl only (no curl/wget)" \
    "$(grep -q 'openssl' "$GENERATE_TLS" && ! grep -Eq 'curl|wget' "$GENERATE_TLS"; echo $?)"
  require_condition "generate-tls.sh refuses to overwrite an existing certificate without --force" \
    "$(grep -q -- '--force' "$GENERATE_TLS"; echo $?)"
else
  fail "generate-tls.sh SAN/force checks (file missing)"
fi

# --- 7. No OPNsense-modifying command anywhere -------------------------------
# E1/VLAN/NAT/filtering stay manual: scripts only print the plan and run
# read-only TCP/TLS checks.

OPNSENSE_FORBIDDEN=(
  'configctl' 'curl[[:space:]]+-X' 'curl[[:space:]]+--request'
  '-X[[:space:]]+POST' '-X[[:space:]]+PUT' '-X[[:space:]]+DELETE'
  'pfctl' 'ssh[[:space:]]'
)

for f in "$PRINT_PLAN" "$VERIFY_OPNSENSE"; do
  [[ -f "$f" ]] || { fail "no OPNsense modification command in $(rel "$f") (file missing)"; continue; }
  bad=0
  for pattern in "${OPNSENSE_FORBIDDEN[@]}"; do
    if grep -Eq -- "$pattern" <(code_lines "$f"); then
      bad=1
      fail "no OPNsense modification command ($pattern) in $(rel "$f")"
    fi
  done
  if grep -Eq '[^a-zA-Z]docker[[:space:]]' <(code_lines "$f"); then
    bad=1
    fail "no docker command in $(rel "$f") (read-only TCP/TLS or print only)"
  fi
  if [[ "$bad" -eq 0 ]]; then
    pass "no OPNsense modification command in $(rel "$f")"
  fi
done

if [[ -f "$VERIFY_OPNSENSE" ]]; then
  require_condition "verify-opnsense.sh only performs TCP/TLS checks (openssl s_client or /dev/tcp)" \
    "$(grep -Eq 'openssl s_client|/dev/tcp' "$VERIFY_OPNSENSE"; echo $?)"
fi

# --- 8. prepare-offline-bundle.sh: connected-host-only, refuses lab, no pull

if [[ -f "$PREPARE_BUNDLE" ]]; then
  require_condition "prepare-offline-bundle.sh sets CONNECTED_HOST_ONLY=1" \
    "$(grep -q 'CONNECTED_HOST_ONLY=1' "$PREPARE_BUNDLE"; echo $?)"
  require_condition "prepare-offline-bundle.sh refuses the lab LAN address (192.168.10.)" \
    "$(grep -q '192\.168\.10\.' "$PREPARE_BUNDLE"; echo $?)"
  require_condition "prepare-offline-bundle.sh refuses the lab WAN address (10.85.4.)" \
    "$(grep -q '10\.85\.4\.' "$PREPARE_BUNDLE"; echo $?)"
  require_condition "prepare-offline-bundle.sh exports images with docker save (not pull)" \
    "$(grep -q 'docker save' "$PREPARE_BUNDLE"; echo $?)"
  require_condition "prepare-offline-bundle.sh writes a .sha256 checksum" \
    "$(grep -q 'sha256sum' "$PREPARE_BUNDLE"; echo $?)"
else
  fail "prepare-offline-bundle.sh checks (file missing)"
fi

# --- 9. prepare-runtime-secrets.sh: restrictive perms, idempotent ----------

if [[ -f "$PREPARE_SECRETS" ]]; then
  require_condition "prepare-runtime-secrets.sh sets restrictive permissions (chmod 600/700)" \
    "$(grep -Eq 'chmod[[:space:]]+(600|700)' "$PREPARE_SECRETS"; echo $?)"
  require_condition "prepare-runtime-secrets.sh does not overwrite an existing secret" \
    "$(grep -Eq '\[\[ ! -f' "$PREPARE_SECRETS"; echo $?)"
  require_condition "prepare-runtime-secrets.sh writes under deploiement/state (excluded from Git)" \
    "$(grep -q 'mv_state_dir' "$PREPARE_SECRETS"; echo $?)"
else
  fail "prepare-runtime-secrets.sh checks (file missing)"
fi

# --- Summary -----------------------------------------------------------------

printf '[MaisonVerte] %d checks run, %d failed\n' "$CHECKS" "$FAILURES"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
