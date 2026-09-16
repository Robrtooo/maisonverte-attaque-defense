#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd)"
F=0
ok(){ printf '[MaisonVerte] PASS: %s\n' "$1"; }
ko(){ printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; F=$((F+1)); }
has(){ grep -q "$2" "$1" && ok "$3" || ko "$3"; }
no(){ grep -Eq "$2" "$1" && ko "$3" || ok "$3"; }

ELK="$ROOT/deploiement/50-admin/services/elk/compose.yaml"
INSTALL="$ROOT/deploiement/50-admin/install-elk-detection.sh"
FB="$ROOT/deploiement/50-admin/services/elk/filebeat.yml"

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

printf '[MaisonVerte] detection failures=%d\n' "$F"
exit "$F"
