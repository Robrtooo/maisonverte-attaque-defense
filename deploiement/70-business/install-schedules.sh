#!/usr/bin/env bash
# Install deterministic cron entries for business proof workflows.
set -Eeuo pipefail
WORKFLOW_VERSION="1.0.0"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command install
[[ "${EUID:-$(id -u)}" -eq 0 ]] || mv_die "install-schedules.sh must run as root"

SCHEDULE_STATE="$(mv_state_dir)/business/maisonverte-business.cron"
mkdir -p "$(dirname -- "$SCHEDULE_STATE")"

schedule="SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
10 2 * * * root $SCRIPT_DIR/demo-nightly-sales.sh >> /var/log/maisonverte-business.log 2>&1
30 6 * * 1 root $SCRIPT_DIR/demo-search.sh >> /var/log/maisonverte-business.log 2>&1"

printf '%s\n' "$schedule" >"$SCHEDULE_STATE"
install -m 0644 "$SCHEDULE_STATE" /etc/cron.d/maisonverte-business
mv_log "business schedules installed in /etc/cron.d/maisonverte-business"
