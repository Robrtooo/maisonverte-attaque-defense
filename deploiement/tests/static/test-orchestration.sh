#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd)"
F=0
ok(){ printf '[MaisonVerte] PASS: %s\n' "$1"; }
ko(){ printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; F=$((F+1)); }

FILES=(
  "$ROOT/deploiement/90-orchestration/deploy-profile.sh"
  "$ROOT/deploiement/90-orchestration/deploy-maisonverte.sh"
  "$ROOT/deploiement/90-orchestration/validate-static.sh"
)
for f in "${FILES[@]}"; do [[ -f "$f" ]] && ok "file exists ${f#"$ROOT"/}" || ko "file exists ${f#"$ROOT"/}"; done
bash -n "${FILES[@]}" && ok "orchestration bash -n" || ko "orchestration bash -n"
grep -q 'stop-heavy' "${FILES[0]}" && ok "stop-heavy profile exists" || ko "stop-heavy profile exists"
grep -q 'full-risky' "${FILES[1]}" && ok "full-risky explicit mode exists" || ko "full-risky explicit mode exists"
grep -q 'chain-a | chain-b | chain-c' "${FILES[1]}" && ok "default avoids all chains" || ko "default avoids all chains"
! grep -Eiq 'apt-get|docker pull|suricata-update|git clone|wget |curl -O' "${FILES[@]}" && ok "no online install command" || ko "no online install command"

printf '[MaisonVerte] orchestration failures=%d\n' "$F"
exit "$F"
