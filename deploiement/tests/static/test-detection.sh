#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd)"
F=0
ok(){ printf '[MaisonVerte] PASS: %s\n' "$1"; }
ko(){ printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; F=$((F+1)); }
has(){ grep -q -- "$2" "$1" && ok "$3" || ko "$3"; }
no(){ grep -Eq -- "$2" "$1" && ko "$3" || ok "$3"; }

ELK="$ROOT/deploiement/50-admin/services/elk/compose.yaml"
INSTALL="$ROOT/deploiement/50-admin/install-elk-detection.sh"
FB="$ROOT/deploiement/50-admin/services/elk/filebeat.yml"
RULES="$ROOT/deploiement/80-detection/tp-local.rules"
NOTES="$ROOT/deploiement/80-detection/configure-suricata-notes.sh"
TRIGGER="$ROOT/deploiement/80-detection/trigger-suricata-rules.sh"

[[ -f "$ELK" && -f "$INSTALL" && -f "$FB" ]] && ok "ELK files exist" || ko "ELK files exist"
bash -n "$INSTALL" "$ROOT/deploiement/80-detection/configure-suricata-notes.sh" "$ROOT/deploiement/80-detection/verify-detection.sh" && ok "detection scripts bash -n" || ko "detection scripts bash -n"
has "$ELK" "127.0.0.1:5601:5601" "Kibana loopback only"
has "$ELK" "net-admin" "ELK on admin network"
has "$ELK" "maisonverte-defense" "defensive cluster name"
has "$ELK" "mem_limit: 1024m" "Elasticsearch memory capped"
has "$ELK" "elk-esdata:/usr/share/elasticsearch/data" "Elasticsearch uses writable named volume"
has "$FB" "/var/lib/docker/containers" "Filebeat reads Docker json logs"
has "$ELK" "filebeat test output --strict.perms=false" "Filebeat healthcheck accepts read-only host config"
has "$ROOT/deploiement/80-detection/verify-detection.sh" "filebeat test output --strict.perms=false" "Filebeat verification accepts read-only host config"
no "$ELK" "privileged: true|network_mode: host|:latest" "no risky compose primitive"
no "$ELK" "docker.sock" "no docker socket mounted"
no "$INSTALL" "apt-get|docker pull|suricata-update|git clone|wget |curl -O" "no online install command"

[[ -f "$RULES" ]] && ok "Suricata local rules exist" || ko "Suricata local rules exist"
sid_count="$(grep -Eo 'sid:[0-9]+' "$RULES" | cut -d: -f2 | wc -l)"
unique_sid_count="$(grep -Eo 'sid:[0-9]+' "$RULES" | cut -d: -f2 | sort -nu | wc -l)"
[[ "$sid_count" -eq "$unique_sid_count" ]] && ok "Suricata SIDs are unique" || ko "Suricata SIDs are unique"
[[ "$(grep -Eo 'sid:[0-9]+' "$RULES" | cut -d: -f2 | sort -n | head -1)" -ge 9000001 ]] && ok "Suricata SID range starts at 9000001+" || ko "Suricata SID range starts at 9000001+"

for service in E2 E3 E5 E6 E7 E8 E9 E10 E11 E12 E13 E14; do
  grep -q "MV $service " "$RULES" && ok "targeted rule exists for $service" || ko "targeted rule exists for $service"
done

for family in "MV GLOBAL traversal" "MV GLOBAL suspicious HTTP method" "MV GLOBAL exploit payload" "MV GLOBAL sensitive service access"; do
  grep -q "$family" "$RULES" && ok "global rule exists: $family" || ko "global rule exists: $family"
done

has "$NOTES" "9000026-9000029 SNI TLS" "NSM notes use current SNI SID mapping"
has "$NOTES" "9000030-9000033 global" "NSM notes document global SID range"
[[ -f "$TRIGGER" ]] && ok "Suricata trigger script exists" || ko "Suricata trigger script exists"
if [[ -f "$TRIGGER" ]]; then
  bash -n "$TRIGGER" && ok "Suricata trigger script bash -n" || ko "Suricata trigger script bash -n"
  has "$TRIGGER" "--path-as-is" "trigger preserves traversal URI"
  has "$TRIGGER" "GLUE_SHELL" "trigger sends harmless exploit marker"
fi

printf '[MaisonVerte] detection failures=%d\n' "$F"
exit "$F"
