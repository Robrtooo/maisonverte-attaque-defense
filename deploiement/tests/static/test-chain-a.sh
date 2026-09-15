#!/usr/bin/env bash
# Static and mocked-functional tests for Task 4 (chain A E7-E8-E10).
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploiement"

E7_INSTALL="$DEPLOY_DIR/20-srv/install-e7-product-search.sh"
E8_INSTALL="$DEPLOY_DIR/20-srv/install-e8-session-cache.sh"
E10_INSTALL="$DEPLOY_DIR/30-data/install-e10-catalog-orders.sh"
E7_COMPOSE="$DEPLOY_DIR/20-srv/services/e7/compose.yaml"
E8_COMPOSE="$DEPLOY_DIR/20-srv/services/e8/compose.yaml"
E10_COMPOSE="$DEPLOY_DIR/30-data/services/e10/compose.yaml"
E7_SEED="$DEPLOY_DIR/20-srv/services/e7/seed-search.sh"
E8_SEED="$DEPLOY_DIR/20-srv/services/e8/seed-cache.sh"
E10_SEED="$DEPLOY_DIR/30-data/services/e10/seed-database.sh"
E10_SCHEMA="$DEPLOY_DIR/30-data/services/e10/init/01-schema.sql"

CHECKS=0
FAILURES=0

pass() { CHECKS=$((CHECKS + 1)); printf '[MaisonVerte] PASS: %s\n' "$1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); printf '[MaisonVerte] FAIL: %s\n' "$1" >&2; }
require() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

for f in "$E7_INSTALL" "$E8_INSTALL" "$E10_INSTALL" "$E7_COMPOSE" "$E8_COMPOSE" "$E10_COMPOSE" "$E7_SEED" "$E8_SEED" "$E10_SEED" "$E10_SCHEMA"; do
  [[ -f "$f" ]] && pass "file exists: ${f#"$REPO_ROOT"/}" || fail "file exists: ${f#"$REPO_ROOT"/}"
done

for f in "$E7_INSTALL" "$E8_INSTALL" "$E10_INSTALL" "$E7_SEED" "$E8_SEED" "$E10_SEED"; do
  [[ -f "$f" ]] && bash -n "$f" && pass "bash -n: ${f#"$REPO_ROOT"/}" || fail "bash -n: ${f#"$REPO_ROOT"/}"
done

require "E7 uses Elasticsearch 1.4.2" "grep -q 'vulhub/elasticsearch:1.4.2' '$E7_COMPOSE'"
require "E8 uses Redis 4.0.14" "grep -q 'vulhub/redis:4.0.14' '$E8_COMPOSE'"
require "E10 uses PostgreSQL 10.7" "grep -q 'vulhub/postgres:10.7' '$E10_COMPOSE'"
require "E7 joins mv-a-edge and mv-a-core" "grep -q 'mv-a-edge' '$E7_COMPOSE' && grep -q 'mv-a-core' '$E7_COMPOSE'"
require "E8 joins mv-a-core and mv-a-data" "grep -q 'mv-a-core' '$E8_COMPOSE' && grep -q 'mv-a-data' '$E8_COMPOSE'"
require "E10 joins only mv-a-data" "grep -q 'mv-a-data' '$E10_COMPOSE' && ! grep -q 'mv-a-core' '$E10_COMPOSE' && ! grep -q 'mv-a-edge' '$E10_COMPOSE'"
require "E7 exposes only 9200 and never 9300" "grep -q '\"9200\"' '$E7_COMPOSE' && ! grep -q '9300' '$E7_COMPOSE'"
require "no chain A compose publishes host ports" "! grep -R '^ *ports:' '$E7_COMPOSE' '$E8_COMPOSE' '$E10_COMPOSE'"
require "no latest, privileged, host network or docker.sock" "! grep -RE ':latest|privileged:|network_mode:[[:space:]]*host|/var/run/docker.sock' '$E7_COMPOSE' '$E8_COMPOSE' '$E10_COMPOSE'"
pull_policy_count="$(grep -R 'pull_policy: never' "$E7_COMPOSE" "$E8_COMPOSE" "$E10_COMPOSE" | wc -l)"
if [[ "$pull_policy_count" -eq 3 ]]; then
  pass "all chain A compose files use pull_policy never"
else
  fail "all chain A compose files use pull_policy never"
fi

mem_total="$(awk '/mem_limit:/ {gsub(/[^0-9]/, "", $2); total += $2} END {print total + 0}' "$E7_COMPOSE" "$E8_COMPOSE" "$E10_COMPOSE")"
if [[ "$mem_total" -eq 1536 ]]; then
  pass "memory budget is exactly 1536m"
else
  fail "memory budget is exactly 1536m"
fi
require "E7 seed creates 40 product docs" "grep -q 'seq 1 40' '$E7_SEED'"
require "E7 seed runs through docker exec because E7 has no host port" "grep -q 'docker exec' '$E7_SEED' && grep -q '127.0.0.1:9200' '$E7_SEED'"
require "E8 seed runs redis-cli through docker exec by default" "grep -q 'docker exec.*redis-cli' '$E8_SEED' && grep -q 'REDIS_CLI' '$E8_SEED'"
require "E7 seed does not index E7 proof file" "! grep -Eiq 'flag|/opt/maisonverte|mv_flag_value' '$E7_SEED'"
require "E8 has no requirepass" "! grep -qi 'requirepass' '$E8_COMPOSE'"
require "E8 uses a Redis volume" "grep -q 'e8_redis' '$E8_COMPOSE'"
require "E8 stores one libpq credential key" "grep -q 'maisonverte:chain:a:e10:libpq' '$E8_SEED' && grep -q 'host=catalog-data01 port=5432' '$E8_SEED'"
if grep -q 'SLAVEOF NO ONE' "$E8_SEED" \
  && grep -q 'expect_reply "OK" FLUSHALL' "$E8_SEED" \
  && grep -q 'expect_reply "1" DBSIZE' "$E8_SEED" \
  && grep -Fq 'expect_reply "$credential" GET' "$E8_SEED"; then
  pass "E8 reset detaches rogue master and verifies exact replies"
else
  fail "E8 reset detaches rogue master and verifies exact replies"
fi
require "E10 has persistent PGDATA volume" "grep -q 'e10_pgdata' '$E10_COMPOSE'"
require "E10 uses mounted flag proof and COPY PROGRAM table" "grep -q '/opt/maisonverte/flag.txt' '$E10_COMPOSE' && grep -q 'cmd_exec' '$E10_SCHEMA'"
require "flags are resolved by service id" "grep -q 'mv_flag_value E7' '$E7_INSTALL' && grep -q 'mv_flag_value E8' '$E8_INSTALL' && grep -q 'mv_flag_value E10' '$E10_INSTALL'"

mock_dir="$(mktemp -d)"
trap 'rm -rf "$mock_dir"' EXIT
cat >"$mock_dir/redis-cli" <<'MOCK'
#!/usr/bin/env bash
shift 2
printf '%s\n' "$*" >>"$REDIS_CALL_LOG"
case "$1" in
  SLAVEOF)
    [[ "$2 $3" == "NO ONE" ]] && echo OK || echo "ERR bad slaveof"
    ;;
  FLUSHALL)
    : >"$REDIS_STATE"
    echo OK
    ;;
  SET)
    printf '%s' "$3" >"$REDIS_STATE"
    echo OK
    ;;
  DBSIZE)
    echo "${MOCK_DBSIZE:-1}"
    ;;
  GET)
    cat "$REDIS_STATE"
    ;;
  *)
    echo "ERR unexpected"
    ;;
esac
MOCK
chmod +x "$mock_dir/redis-cli"
export REDIS_CLI="$mock_dir/redis-cli"
export REDIS_CALL_LOG="$mock_dir/calls"
export REDIS_STATE="$mock_dir/value"
export E10_DB_PASS="pa/ss+with'quote\slash"
if "$E8_SEED" >/dev/null 2>&1; then
  pass "mocked Redis reset succeeds with reserved-character password"
else
  fail "mocked Redis reset succeeds with reserved-character password"
fi
require "mocked Redis reset calls commands in safe order" "printf '%s\n' 'SLAVEOF NO ONE' 'FLUSHALL' | diff - <(sed -n '1,2p' '$REDIS_CALL_LOG') >/dev/null"
MOCK_DBSIZE=2 "$E8_SEED" >/dev/null 2>&1 && fail "mocked Redis reset rejects extra keys" || pass "mocked Redis reset rejects extra keys"
if [[ "$FAILURES" -eq 0 ]]; then
  printf '[MaisonVerte] OK: %s checks passed\n' "$CHECKS"
  exit 0
fi
printf '[MaisonVerte] FAILED: %s/%s checks failed\n' "$FAILURES" "$CHECKS" >&2
exit 1
