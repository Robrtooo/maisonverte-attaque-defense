#!/usr/bin/env bash
# deploiement/00-infra/preflight.sh
#
# Read-only pre-deployment checks: Docker, Compose, CPU architecture, RAM,
# free disk space, availability of the single public host port and pinned
# images already present locally (per images.lock, pull_policy: never).
#
# This script never mutates host state. It never calls `docker pull`, a
# package manager, `docker run`, `docker network create`, `docker load` or
# `docker save` — it only inspects.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

MIN_RAM_MB="${MV_PREFLIGHT_MIN_RAM_MB:-6144}"
MIN_DISK_MB="${MV_PREFLIGHT_MIN_DISK_MB:-20480}"

declare -a REQUIRED_IMAGES=()
case "${1:-}" in
  "")
    images_lock="$MV_CONFIG_DIR/images.lock"
    mv_require_file "$images_lock"
    mapfile -t REQUIRED_IMAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$images_lock")
    ;;
  --images)
    shift
    REQUIRED_IMAGES=("$@")
    ;;
  --no-images)
    ;;
  *)
    mv_die "usage: $0 [--images IMAGE ...|--no-images]"
    ;;
esac

# Single mandatory public bind (ARCHITECTURE.md: "L'unique publication
# externe est 10.85.4.10:443", NAT'd by OPNsense to E2 at 192.168.10.50:443).
# Kibana's optional loopback bind (127.0.0.1:5601, Task 8) is not a public
# bind and is out of scope for this preflight.
REQUIRED_PORTS=("192.168.10.50:443")

FAILURES=0

check() {
  # check <description> <0-or-nonzero-exit-code>
  if [[ "$2" -eq 0 ]]; then
    mv_log "OK: $1"
  else
    mv_log "FAIL: $1"
    FAILURES=$((FAILURES + 1))
  fi
}

mv_log "=== MaisonVerte preflight ==="

# --- Docker & Compose --------------------------------------------------
mv_require_command docker
check "docker command available" 0

if docker compose version >/dev/null 2>&1; then
  check "docker compose plugin available" 0
else
  check "docker compose plugin available" 1
fi

# --- CPU architecture --------------------------------------------------
arch="$(uname -m)"
if [[ "$arch" == "x86_64" || "$arch" == "amd64" ]]; then
  check "host architecture is amd64 (found: $arch)" 0
else
  check "host architecture is amd64 (found: $arch)" 1
fi

# --- RAM -----------------------------------------------------------------
if [[ -r /proc/meminfo ]]; then
  total_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  total_mb=$((total_kb / 1024))
  if ((total_mb >= MIN_RAM_MB)); then
    check "RAM >= ${MIN_RAM_MB}MiB (found: ${total_mb}MiB)" 0
  else
    check "RAM >= ${MIN_RAM_MB}MiB (found: ${total_mb}MiB)" 1
  fi
else
  check "RAM >= ${MIN_RAM_MB}MiB (unable to read /proc/meminfo)" 1
fi

# --- Disk space ------------------------------------------------------------
avail_mb="$(df -Pm "$(mv_repo_root)" | awk 'NR==2 {print $4}')"
if [[ -n "$avail_mb" ]] && ((avail_mb >= MIN_DISK_MB)); then
  check "free disk space >= ${MIN_DISK_MB}MiB (found: ${avail_mb}MiB)" 0
else
  check "free disk space >= ${MIN_DISK_MB}MiB (found: ${avail_mb:-unknown}MiB)" 1
fi

# --- Ports -----------------------------------------------------------------
for hostport in "${REQUIRED_PORTS[@]}"; do
  port="${hostport##*:}"
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$"; then
      check "port $hostport is free" 1
    else
      check "port $hostport is free" 0
    fi
  else
    check "port $hostport is free (ss not available, skipped)" 0
  fi
done

# --- Images already present locally (never docker pull) --------------------
for image in "${REQUIRED_IMAGES[@]}"; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    check "image present locally: $image" 0
  else
    check "image present locally: $image (run import-offline-images.sh)" 1
  fi
done

mv_log "=== preflight: ${FAILURES} failure(s) ==="
if ((FAILURES > 0)); then
  exit 1
fi
exit 0
