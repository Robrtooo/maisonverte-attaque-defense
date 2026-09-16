#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd)"
F=0
ok(){ printf '[MaisonVerte] PASS: %s\n' "$1"; }
ko(){ printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; F=$((F+1)); }

FILES=(
  "$ROOT/deploiement/00-infra/preflight.sh"
  "$ROOT/deploiement/90-orchestration/deploy-profile.sh"
  "$ROOT/deploiement/90-orchestration/deploy-maisonverte.sh"
  "$ROOT/deploiement/90-orchestration/validate-static.sh"
  "$ROOT/deploiement/90-orchestration/check-all-services.sh"
)
for f in "${FILES[@]}"; do [[ -f "$f" ]] && ok "file exists ${f#"$ROOT"/}" || ko "file exists ${f#"$ROOT"/}"; done
bash -n "${FILES[@]}" && ok "orchestration bash -n" || ko "orchestration bash -n"
grep -q 'stop-heavy' "${FILES[1]}" && ok "stop-heavy profile exists" || ko "stop-heavy profile exists"
grep -q 'full-risky' "${FILES[2]}" && ok "full-risky explicit mode exists" || ko "full-risky explicit mode exists"
grep -q 'chain-a | chain-b | chain-c' "${FILES[2]}" && ok "default avoids all chains" || ko "default avoids all chains"
! grep -Eiq 'apt-get|docker pull|suricata-update|git clone|wget |curl -O' "${FILES[@]:1:3}" && ok "no online install command" || ko "no online install command"
grep -q -- '--images' "${FILES[0]}" && ok "preflight supports explicit image selection" || ko "preflight supports explicit image selection"
grep -q 'preflight.sh" --images' "${FILES[1]}" && ok "profiles preflight only their images" || ko "profiles preflight only their images"
grep -q -- '--skip-port-check --images' "${FILES[1]}" && ok "non-DMZ profiles ignore occupied public port" || ko "non-DMZ profiles ignore occupied public port"
grep -q 'E10_DB_PASS=static-validation-only' "${FILES[3]}" && ok "static compose validation supplies non-secret placeholder" || ko "static compose validation supplies non-secret placeholder"
grep -q 'only E2 and Kibana publish host ports' "${FILES[4]}" && ok "global check validates published ports" || ko "global check validates published ports"
grep -q 'Filebeat output reaches Elasticsearch' "${FILES[4]}" && ok "global check validates ELK ingestion path" || ko "global check validates ELK ingestion path"

printf '[MaisonVerte] orchestration failures=%d\n' "$F"
exit "$F"
