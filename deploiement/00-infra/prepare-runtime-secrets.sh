#!/usr/bin/env bash
# deploiement/00-infra/prepare-runtime-secrets.sh
#
# Idempotently ensures a single named runtime secret exists under
# deploiement/state/secrets/ (excluded from Git) with restrictive
# permissions, and prints its value on stdout. Later install-eX scripts
# call this to obtain generated credentials without ever hardcoding a
# secret value in a script or compose.yaml (flag values themselves still
# come exclusively from enonce/flags-G04.csv via lib/common.sh:
# mv_flag_value — this script is only for non-flag runtime credentials
# such as generated database passwords).
#
# Uses only the local `openssl` binary; never calls a package manager or
# any network command.
#
# Usage: prepare-runtime-secrets.sh <secret-name> [byte-length]

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command openssl

NAME="${1:-}"
LENGTH="${2:-24}"

if [[ -z "$NAME" ]]; then
  mv_die "usage: prepare-runtime-secrets.sh <secret-name> [byte-length]"
fi
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  mv_die "invalid secret name: $NAME"
fi

SECRETS_DIR="$(mv_state_dir)/secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

SECRET_FILE="$SECRETS_DIR/$NAME"

if [[ ! -f "$SECRET_FILE" ]]; then
  mv_log "generating runtime secret: $NAME"
  umask 077
  openssl rand -base64 "$LENGTH" | tr -d '\n=' >"$SECRET_FILE"
  chmod 600 "$SECRET_FILE"
else
  mv_log "runtime secret already present, reusing: $NAME"
fi

cat "$SECRET_FILE"
