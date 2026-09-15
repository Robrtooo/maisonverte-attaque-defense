#!/usr/bin/env bash
# Install E14 Jenkins 2.441 with CVE-2024-23897 reachable only from Chain B.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_load_env "$MV_CONFIG_DIR/services.env"

COMPOSE_FILE="$SCRIPT_DIR/services/e14/compose.yaml"
SERVICE_STATE="$(mv_state_dir)/services/e14"
SECRETS_SCRIPT="$MV_DEPLOY_DIR/00-infra/prepare-runtime-secrets.sh"

mv_require_file "$SECRETS_SCRIPT"
mkdir -p "$SERVICE_STATE"
chmod 700 "$SERVICE_STATE"
umask 077
mv_flag_value E14 >"$SERVICE_STATE/flag.txt"
chmod 600 "$SERVICE_STATE/flag.txt"

export MV_E14_ADMIN_PASSWORD
MV_E14_ADMIN_PASSWORD="$($SECRETS_SCRIPT e14-jenkins-admin-password)"

mv_log "starting E14 Jenkins with project $E14_PROJECT"
mv_compose "$E14_PROJECT" "$COMPOSE_FILE" up -d
mv_wait_healthy "$E14_CONTAINER" 180
mv_log "E14 Jenkins is healthy"
