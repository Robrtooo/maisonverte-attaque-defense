#!/usr/bin/env bash
# Reset Redis after rogue-master abuse and seed exactly one E10 credential.
set -Eeuo pipefail

REDIS_CLI="${REDIS_CLI:-}"
REDIS_CONTAINER="${REDIS_CONTAINER:-cache-srv01}"
REDIS_KEY="${REDIS_KEY:-maisonverte:chain:a:e10:libpq}"
E10_DB_USER="${E10_DB_USER:-mv_catalog_admin}"
E10_DB_NAME="${E10_DB_NAME:-maisonverte}"
E10_DB_PASS="${E10_DB_PASS:-}"

if [[ -z "$E10_DB_PASS" ]]; then
  echo "[MaisonVerte] ERROR: E10_DB_PASS is required" >&2
  exit 1
fi

libpq_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\'/\\\'}"
  printf "'%s'" "$value"
}

redis_cmd() {
  if [[ -n "$REDIS_CLI" ]]; then
    "$REDIS_CLI" -h "$REDIS_CONTAINER" "$@"
  else
    docker exec "$REDIS_CONTAINER" redis-cli "$@"
  fi
}

expect_reply() {
  local expected="$1"
  shift
  local reply
  reply="$(redis_cmd "$@" | tr -d '\r')"
  if [[ "$reply" != "$expected" ]]; then
    echo "[MaisonVerte] ERROR: redis command '$*' returned '$reply', expected '$expected'" >&2
    exit 1
  fi
}

credential="host=catalog-data01 port=5432 dbname=$E10_DB_NAME user=$E10_DB_USER password=$(libpq_escape "$E10_DB_PASS")"

expect_reply "OK" SLAVEOF NO ONE
expect_reply "OK" FLUSHALL
expect_reply "OK" SET "$REDIS_KEY" "$credential"
expect_reply "1" DBSIZE
expect_reply "$credential" GET "$REDIS_KEY"
