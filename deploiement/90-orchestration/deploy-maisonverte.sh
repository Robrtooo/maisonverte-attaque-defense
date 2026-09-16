#!/usr/bin/env bash
# RAM-aware master deployment. Avoids starting every heavy chain at once.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mode="${1:-poc}"

run_profile() {
  "$SCRIPT_DIR/deploy-profile.sh" "$1"
}

case "$mode" in
  poc)
    run_profile foundation
    run_profile dmz
    run_profile business
    mv_log "POC base deployed. Add one chain at a time: chain-a | chain-b | chain-c. Detection optional."
    ;;
  chain-a|chain-b|chain-c|business|detection|foundation|dmz|stop-heavy)
    run_profile "$mode"
    ;;
  full-risky)
    mv_log "WARNING: full-risky may exceed 4-8 GiB hosts. Prefer poc + one chain."
    run_profile foundation
    run_profile dmz
    run_profile chain-a
    run_profile chain-b
    run_profile chain-c
    run_profile business
    run_profile detection
    ;;
  *)
    mv_die "usage: $0 poc|foundation|dmz|chain-a|chain-b|chain-c|business|detection|stop-heavy|full-risky"
    ;;
esac
