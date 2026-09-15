#!/usr/bin/env bash
# deploiement/00-infra/generate-tls.sh
#
# Generates a local, self-signed TLS certificate/key pair for E2's public
# TLS termination, with subjectAltName covering the wildcard
# *.maisonverte.fr (and the bare maisonverte.fr apex) used by the four
# public hostnames documented in ARCHITECTURE.md:
#   shop.maisonverte.fr, api.maisonverte.fr, vendeurs.maisonverte.fr,
#   cache.maisonverte.fr
#
# Uses only the local `openssl` binary: no ACME client, no CA download, no
# network call of any kind.
#
# An existing certificate/key pair is never overwritten unless --force is
# passed explicitly.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command openssl

FORCE=0
for arg in "$@"; do
  case "$arg" in
  --force) FORCE=1 ;;
  *) mv_die "unknown argument: $arg (usage: generate-tls.sh [--force])" ;;
  esac
done

TLS_DIR="$(mv_state_dir)/tls"
mkdir -p "$TLS_DIR"
CERT_FILE="$TLS_DIR/maisonverte.crt"
KEY_FILE="$TLS_DIR/maisonverte.key"

if [[ -f "$CERT_FILE" || -f "$KEY_FILE" ]] && [[ "$FORCE" -ne 1 ]]; then
  mv_die "TLS material already present at $TLS_DIR (use --force to regenerate): $CERT_FILE"
fi

mv_log "generating self-signed certificate (SAN: DNS:*.maisonverte.fr, DNS:maisonverte.fr)"

umask 077
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -days 825 \
  -subj "/C=FR/O=MaisonVerte Lab/CN=*.maisonverte.fr" \
  -addext "subjectAltName=DNS:*.maisonverte.fr,DNS:maisonverte.fr" \
  >/dev/null 2>&1

chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

mv_log "TLS certificate written: $CERT_FILE"
mv_log "TLS private key written: $KEY_FILE"
