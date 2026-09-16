#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"

for t in deploiement/tests/static/test-*.sh; do
  bash "$t"
done

find deploiement -name compose.yaml -print0 | while IFS= read -r -d '' compose; do
  docker compose -f "$compose" config --quiet
done
