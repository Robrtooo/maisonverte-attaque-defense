#!/usr/bin/env bash
# deploiement/00-infra/verify-opnsense.sh
#
# Read-only verification of the OPNsense-facing publication: a TCP connect
# check against the public bind, then a TLS handshake per public SNI name.
# Never modifies OPNsense: no API call, no SSH session, no `configctl`.
# Only bash's built-in /dev/tcp and `openssl s_client` (read-only, no
# client certificate, no write operation) are used.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command openssl

WAN_HOST="${MV_WAN_HOST:-10.85.4.10}"
WAN_PORT="${MV_WAN_PORT:-443}"
SNI_NAMES=(shop.maisonverte.fr api.maisonverte.fr vendeurs.maisonverte.fr cache.maisonverte.fr)

FAILURES=0

mv_log "=== verify-opnsense: read-only TCP/TLS checks against ${WAN_HOST}:${WAN_PORT} ==="

if (exec 3<>"/dev/tcp/${WAN_HOST}/${WAN_PORT}") 2>/dev/null; then
  # fd 3 was opened and closed inside the subshell above; nothing to close
  # here in the parent shell.
  mv_log "OK: TCP connect ${WAN_HOST}:${WAN_PORT}"
else
  mv_log "FAIL: TCP connect ${WAN_HOST}:${WAN_PORT}"
  FAILURES=$((FAILURES + 1))
fi

for sni in "${SNI_NAMES[@]}"; do
  if echo | openssl s_client -connect "${WAN_HOST}:${WAN_PORT}" -servername "$sni" \
    2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
    mv_log "OK: TLS handshake for SNI $sni"
  else
    mv_log "FAIL: TLS handshake for SNI $sni"
    FAILURES=$((FAILURES + 1))
  fi
done

mv_log "=== verify-opnsense: ${FAILURES} failure(s) ==="
if ((FAILURES > 0)); then
  exit 1
fi
exit 0
