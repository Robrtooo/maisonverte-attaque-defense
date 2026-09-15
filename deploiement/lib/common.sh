#!/usr/bin/env bash
# deploiement/lib/common.sh
#
# Shared bash library for every MaisonVerte deployment script. It is always
# sourced, never executed directly. It defines strict-mode error handling,
# repository-relative path constants, small guard helpers, environment
# loading, exact flag lookup by flag_id, and thin Docker Compose wrappers.
#
# This library performs no network access and no mutating action on load: it
# only computes paths and defines functions/constants.

# Guard against being sourced twice in the same shell (readonly constants
# below would otherwise raise "readonly variable" errors).
if [[ -n "${MV_COMMON_SH_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
MV_COMMON_SH_LOADED=1

set -Eeuo pipefail

# --- Path constants, derived from this file's own location -----------------

MV_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly MV_LIB_DIR
readonly MV_REPO_ROOT_CONST="$(cd -- "$MV_LIB_DIR/../.." >/dev/null 2>&1 && pwd)"
readonly MV_DEPLOY_DIR="$MV_REPO_ROOT_CONST/deploiement"
readonly MV_CONFIG_DIR="$MV_DEPLOY_DIR/config"
readonly MV_STATE_DIR_CONST="$MV_DEPLOY_DIR/state"
readonly MV_VENDOR_DIR="$MV_DEPLOY_DIR/vendor/vulhub"
readonly MV_ENONCE_DIR="$MV_REPO_ROOT_CONST/enonce"
readonly MV_FLAGS_CSV="$MV_ENONCE_DIR/flags-G04.csv"
readonly MV_FLAGS_MAP="$MV_CONFIG_DIR/flags.map"

# --- Logging -----------------------------------------------------------------

# mv_log <message...>
# Print a message to stderr, prefixed with [MaisonVerte].
mv_log() {
  printf '[MaisonVerte] %s\n' "$*" >&2
}

# mv_die <message...>
# Print an error message to stderr, prefixed with [MaisonVerte], and exit 1.
mv_die() {
  mv_log "ERROR: $*"
  exit 1
}

# --- Path accessors ------------------------------------------------------

# mv_repo_root
# Print the absolute path to the repository root.
mv_repo_root() {
  printf '%s\n' "$MV_REPO_ROOT_CONST"
}

# mv_state_dir
# Print the absolute path to deploiement/state (runtime files, excluded from
# Git), creating it if it does not exist yet.
mv_state_dir() {
  mkdir -p "$MV_STATE_DIR_CONST"
  printf '%s\n' "$MV_STATE_DIR_CONST"
}

# --- Guards ------------------------------------------------------------------

# mv_require_command <command>
# Die if <command> is not available on PATH.
mv_require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    mv_die "required command not found: $cmd"
  fi
}

# mv_require_file <path>
# Die if <path> does not exist or is not a regular file.
mv_require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    mv_die "required file not found: $path"
  fi
}

# --- Environment loading -------------------------------------------------

# mv_load_env <path>
# Die if <path> is missing; otherwise source and export every KEY=VALUE
# assignment it defines. Used for deploiement/config/*.env files.
mv_load_env() {
  local path="$1"
  mv_require_file "$path"
  set -a
  # shellcheck source=/dev/null
  . "$path"
  set +a
}

# --- Flags -----------------------------------------------------------------

# mv_flag_value <service_ref>
# Resolve <service_ref> (e.g. "E10") to its flag_id via config/flags.map,
# then look up the exact flag value for that flag_id in
# enonce/flags-G04.csv. Dies if the service ref has no mapping or the
# flag_id has no matching CSV row. Never duplicates flag values in code.
mv_flag_value() {
  local service_ref="$1"
  mv_require_file "$MV_FLAGS_MAP"
  mv_require_file "$MV_FLAGS_CSV"

  local flag_id
  flag_id="$(awk -F'=' -v ref="$service_ref" \
    '$1==ref {print $2; exit}' "$MV_FLAGS_MAP")"
  if [[ -z "$flag_id" ]]; then
    mv_die "no flag mapping for service ref: $service_ref"
  fi

  local flag_value
  flag_value="$(awk -F',' -v id="$flag_id" \
    'NR>1 && $1==id {print $2; exit}' "$MV_FLAGS_CSV")"
  if [[ -z "$flag_value" ]]; then
    mv_die "no flag value in $MV_FLAGS_CSV for flag_id: $flag_id (service $service_ref)"
  fi

  printf '%s\n' "$flag_value"
}

# --- Compose wrappers --------------------------------------------------------

# mv_compose <project_name> <compose_file> [docker compose args...]
# Run `docker compose` against <compose_file> with a stable
# --project-name. Never executed for this task's tests; callers are
# responsible for actually invoking it once a lab deployment is authorized.
mv_compose() {
  local project="$1"
  local compose_file="$2"
  shift 2
  mv_require_command docker
  mv_require_file "$compose_file"
  docker compose --project-name "$project" -f "$compose_file" "$@"
}

# mv_wait_healthy <container_name> [timeout_seconds]
# Poll `docker inspect` until <container_name> reports a "healthy" health
# status, or die after [timeout_seconds] (default 60).
mv_wait_healthy() {
  local container="$1"
  local timeout="${2:-60}"
  mv_require_command docker

  local waited=0
  local status
  while (( waited < timeout )); do
    status="$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")"
    if [[ "$status" == "healthy" ]]; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  mv_die "container did not become healthy within ${timeout}s: $container"
}
