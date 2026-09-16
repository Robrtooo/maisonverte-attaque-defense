#!/usr/bin/env bash
# Genere des marqueurs inoffensifs pour valider les SID globaux dans EveBox.
set -u

BASE_URL="${1:-http://192.168.10.30:5636}"
SENSITIVE_HOST="${2:-192.168.10.30}"
SENSITIVE_PORT="${3:-5636}"

request() {
  curl --silent --show-error --output /dev/null --max-time 5 "$@" || true
}

printf '[MaisonVerte] trigger SID 9000030: traversal marker\n'
request --path-as-is "$BASE_URL/../../etc/passwd"

printf '[MaisonVerte] trigger SID 9000031: suspicious PUT marker\n'
request --request PUT "$BASE_URL/tp-suricata-method-test"

printf '[MaisonVerte] trigger SID 9000032: exploit body marker\n'
request --request POST --data 'executorHandler=GLUE_SHELL&test=1' "$BASE_URL/tp-suricata-payload-test"

printf '[MaisonVerte] trigger SID 9000033: sensitive service connection\n'
if command -v nc >/dev/null 2>&1; then
  nc -z -w 3 "$SENSITIVE_HOST" "$SENSITIVE_PORT" >/dev/null 2>&1 || true
else
  request "$BASE_URL/"
fi

printf '[MaisonVerte] Termine. Attendre quelques secondes puis filtrer EveBox sur 9000030-9000033.\n'
