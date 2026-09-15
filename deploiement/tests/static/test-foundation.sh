#!/usr/bin/env bash
# Static test for Task 1 (Socle commun, inventaire et snapshot Vulhub).
#
# This test is read-only: it sources deploiement/lib/common.sh, checks every
# public function it must expose, validates the flags.map mapping against
# enonce/flags-G04.csv, and checks the vendored Vulhub snapshot. It never
# invokes docker, curl, git clone or any other mutating/network command.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"
CONFIG_DIR="$DEPLOY_DIR/config"
LIB_DIR="$DEPLOY_DIR/lib"
VENDOR_DIR="$DEPLOY_DIR/vendor/vulhub"
ENONCE_DIR="$REPO_ROOT/enonce"
FLAGS_CSV="$ENONCE_DIR/flags-G04.csv"

EXPECTED_COMMIT="aeaf65793f147f29bd50841ef77f4e9cad07ecc7"

# The 12 Vulhub scenario paths selected in ARCHITECTURE.md, mapped to their
# owning service reference.
declare -A VULHUB_PATHS=(
  [E2]="nginx/insecure-configuration"
  [E3]="wordpress/pwnscriptum"
  [E5]="tomcat/CVE-2017-12615"
  [E6]="ofbiz/CVE-2023-51467"
  [E7]="elasticsearch/CVE-2015-1427"
  [E8]="redis/4-unacc"
  [E9]="samba/CVE-2017-7494"
  [E10]="postgres/CVE-2019-9193"
  [E11]="mongo-express/CVE-2019-10758"
  [E12]="xxl-job/unacc"
  [E13]="struts2/s2-045"
  [E14]="jenkins/CVE-2024-23897"
)

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

# --- 1. Foundation files must exist -----------------------------------------

for f in \
  "$LIB_DIR/common.sh" \
  "$CONFIG_DIR/lab.env.example" \
  "$CONFIG_DIR/networks.env" \
  "$CONFIG_DIR/services.env" \
  "$CONFIG_DIR/flags.map" \
  "$CONFIG_DIR/images.lock" \
  "$VENDOR_DIR/UPSTREAM_COMMIT"
do
  if [[ -f "$f" ]]; then
    pass "file exists: ${f#"$REPO_ROOT"/}"
  else
    fail "file exists: ${f#"$REPO_ROOT"/}"
  fi
done

# --- 2. common.sh must be sourceable and expose the required functions -----

COMMON_SOURCED=0
if [[ -f "$LIB_DIR/common.sh" ]]; then
  # shellcheck source=/dev/null
  if source "$LIB_DIR/common.sh"; then
    COMMON_SOURCED=1
    pass "common.sh sources without error"
  else
    fail "common.sh sources without error"
  fi
else
  fail "common.sh sources without error (file missing)"
fi

if [[ "$COMMON_SOURCED" -eq 1 ]]; then
  if grep -q 'set -Eeuo pipefail' "$LIB_DIR/common.sh"; then
    pass "common.sh uses set -Eeuo pipefail"
  else
    fail "common.sh uses set -Eeuo pipefail"
  fi

  for fn in mv_repo_root mv_state_dir mv_require_command mv_require_file \
    mv_load_env mv_flag_value mv_compose mv_wait_healthy mv_log mv_die
  do
    if declare -F "$fn" >/dev/null 2>&1; then
      pass "common.sh exposes function: $fn"
    else
      fail "common.sh exposes function: $fn"
    fi
  done

  # mv_repo_root must resolve to the repository root.
  root_val="$(mv_repo_root 2>/dev/null || true)"
  require_condition "mv_repo_root resolves to $REPO_ROOT" \
    "$([[ "$root_val" == "$REPO_ROOT" ]]; echo $?)"

  # mv_state_dir must resolve under deploiement/state.
  state_val="$(mv_state_dir 2>/dev/null || true)"
  require_condition "mv_state_dir resolves under deploiement/state" \
    "$([[ "$state_val" == "$DEPLOY_DIR/state" ]]; echo $?)"

  # mv_require_command must succeed for an existing command...
  if ( mv_require_command bash ) >/dev/null 2>&1; then
    pass "mv_require_command succeeds for an existing command"
  else
    fail "mv_require_command succeeds for an existing command"
  fi
  # ...and must die (non-zero exit) for a missing one.
  if ( mv_require_command mv-definitely-not-a-real-command-xyz ) >/dev/null 2>&1; then
    fail "mv_require_command refuses a missing command"
  else
    pass "mv_require_command refuses a missing command"
  fi

  # mv_require_file must succeed for an existing file...
  if ( mv_require_file "$FLAGS_CSV" ) >/dev/null 2>&1; then
    pass "mv_require_file succeeds for an existing file"
  else
    fail "mv_require_file succeeds for an existing file"
  fi
  # ...and must die for a missing one.
  if ( mv_require_file "$CONFIG_DIR/does-not-exist.env" ) >/dev/null 2>&1; then
    fail "mv_require_file refuses a missing file"
  else
    pass "mv_require_file refuses a missing file"
  fi

  # mv_compose and mv_wait_healthy must build docker compose invocations with
  # a stable --project-name, without this test ever executing docker.
  if declare -f mv_compose | grep -q -- '--project-name'; then
    pass "mv_compose uses --project-name"
  else
    fail "mv_compose uses --project-name"
  fi
  if declare -f mv_wait_healthy | grep -q 'docker'; then
    pass "mv_wait_healthy inspects container health via docker"
  else
    fail "mv_wait_healthy inspects container health via docker"
  fi

  # mv_load_env must load networks.env and expose its constants.
  if [[ -f "$CONFIG_DIR/networks.env" ]]; then
    if ( mv_load_env "$CONFIG_DIR/networks.env" && [[ "${NET_DMZ_NAME:-}" == "net-dmz" ]] ) >/dev/null 2>&1; then
      pass "mv_load_env loads networks.env"
    else
      fail "mv_load_env loads networks.env"
    fi
  else
    fail "mv_load_env loads networks.env (file missing)"
  fi

  # mv_flag_value must resolve a real service ref to the exact CSV value...
  if [[ -f "$CONFIG_DIR/flags.map" && -f "$FLAGS_CSV" ]]; then
    e2_flag_id="$(awk -F'=' '$1=="E2"{print $2; exit}' "$CONFIG_DIR/flags.map" 2>/dev/null || true)"
    if [[ -n "$e2_flag_id" ]]; then
      expected_value="$(awk -F',' -v id="$e2_flag_id" 'NR>1 && $1==id {print $2; exit}' "$FLAGS_CSV" 2>/dev/null || true)"
      actual_value="$(mv_flag_value E2 2>/dev/null || true)"
      require_condition "mv_flag_value E2 returns the exact CSV value for flag_id $e2_flag_id" \
        "$([[ -n "$expected_value" && "$actual_value" == "$expected_value" ]]; echo $?)"
    else
      fail "mv_flag_value E2 returns the exact CSV value (no E2 mapping in flags.map)"
    fi
  else
    fail "mv_flag_value E2 returns the exact CSV value (config files missing)"
  fi
  # ...and must refuse (non-zero exit, no value) an absent service ref.
  if absent_val="$( mv_flag_value E999-does-not-exist 2>/dev/null )"; then
    fail "mv_flag_value refuses an absent service ref (got: '$absent_val')"
  else
    pass "mv_flag_value refuses an absent service ref"
  fi
else
  for fn in mv_repo_root mv_state_dir mv_require_command mv_require_file \
    mv_load_env mv_flag_value mv_compose mv_wait_healthy mv_log mv_die
  do
    fail "common.sh exposes function: $fn (common.sh did not source)"
  done
fi

# --- 3. flags.map: exactly 12 distinct mappings, one per vulnerable service -

if [[ -f "$CONFIG_DIR/flags.map" ]]; then
  mapfile -t map_lines < <(grep -Ev '^[[:space:]]*(#|$)' "$CONFIG_DIR/flags.map")
  require_condition "flags.map has exactly 12 mapping lines" \
    "$([[ "${#map_lines[@]}" -eq 12 ]]; echo $?)"

  declare -A seen_refs=()
  declare -A seen_ids=()
  malformed=0
  for line in "${map_lines[@]}"; do
    ref="${line%%=*}"
    id="${line#*=}"
    if [[ -z "$ref" || -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
      malformed=1
    fi
    seen_refs["$ref"]=1
    seen_ids["$id"]=1
  done
  require_condition "flags.map lines are well-formed SERVICE=flag_id" \
    "$([[ "$malformed" -eq 0 ]]; echo $?)"
  require_condition "flags.map has 12 distinct service refs" \
    "$([[ "${#seen_refs[@]}" -eq 12 ]]; echo $?)"
  require_condition "flags.map has 12 distinct flag_id values" \
    "$([[ "${#seen_ids[@]}" -eq 12 ]]; echo $?)"

  missing_ref=0
  for ref in "${!VULHUB_PATHS[@]}"; do
    [[ -n "${seen_refs[$ref]:-}" ]] || missing_ref=1
  done
  require_condition "flags.map covers exactly the 12 vulnerable services (E2,E3,E5-E14)" \
    "$([[ "$missing_ref" -eq 0 && "${#seen_refs[@]}" -eq 12 ]]; echo $?)"
else
  fail "flags.map has exactly 12 mapping lines (file missing)"
fi

# --- 4. Vulhub snapshot: 12 paths present with the exact pinned commit -----

if [[ -f "$VENDOR_DIR/UPSTREAM_COMMIT" ]]; then
  commit_val="$(tr -d '[:space:]' < "$VENDOR_DIR/UPSTREAM_COMMIT")"
  require_condition "UPSTREAM_COMMIT records the exact pinned commit $EXPECTED_COMMIT" \
    "$([[ "$commit_val" == "$EXPECTED_COMMIT" ]]; echo $?)"
else
  fail "UPSTREAM_COMMIT records the exact pinned commit (file missing)"
fi

for ref in "${!VULHUB_PATHS[@]}"; do
  path="${VULHUB_PATHS[$ref]}"
  dir="$VENDOR_DIR/$path"
  if [[ -d "$dir" ]]; then
    pass "vendored Vulhub path present: $path ($ref)"
  else
    fail "vendored Vulhub path present: $path ($ref)"
  fi
  if [[ -f "$dir/docker-compose.yml" || -f "$dir/Dockerfile" ]]; then
    pass "vendored Vulhub path has a compose/Dockerfile: $path"
  else
    fail "vendored Vulhub path has a compose/Dockerfile: $path"
  fi
done

if [[ -d "$VENDOR_DIR" ]]; then
  png_count="$(find "$VENDOR_DIR" -iname '*.png' 2>/dev/null | wc -l | tr -d '[:space:]')"
  require_condition "vendored Vulhub snapshot excludes PNG screenshots" \
    "$([[ "$png_count" -eq 0 ]]; echo $?)"
else
  fail "vendored Vulhub snapshot excludes PNG screenshots (vendor dir missing)"
fi

# --- 5. images.lock: pinned, no floating tags -------------------------------

if [[ -f "$CONFIG_DIR/images.lock" ]]; then
  mapfile -t image_lines < <(grep -Ev '^[[:space:]]*(#|$)' "$CONFIG_DIR/images.lock")
  require_condition "images.lock lists at least one pinned image" \
    "$([[ "${#image_lines[@]}" -gt 0 ]]; echo $?)"

  latest_count=0
  for line in "${image_lines[@]:-}"; do
    [[ "$line" =~ :latest$ ]] && latest_count=$((latest_count + 1))
    [[ "$line" =~ : ]] || latest_count=$((latest_count + 1))
  done
  require_condition "images.lock has no 'latest' tag and every entry is pinned" \
    "$([[ "$latest_count" -eq 0 ]]; echo $?)"
else
  fail "images.lock lists at least one pinned image (file missing)"
fi

# --- 6. .gitignore excludes runtime state -----------------------------------

if [[ -f "$REPO_ROOT/.gitignore" ]] && grep -q 'deploiement/state' "$REPO_ROOT/.gitignore"; then
  pass ".gitignore excludes deploiement/state/"
else
  fail ".gitignore excludes deploiement/state/"
fi

# --- Summary -----------------------------------------------------------------

printf '[MaisonVerte] %d checks run, %d failed\n' "$CHECKS" "$FAILURES"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
