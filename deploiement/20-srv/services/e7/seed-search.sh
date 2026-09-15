#!/usr/bin/env bash
# Seed E7 with searchable products and a limited E8 clue.
set -Eeuo pipefail

CONTAINER="${CONTAINER:-search-srv01}"
ES_URL="${ES_URL:-http://127.0.0.1:9200}"

put_doc() {
  local path="$1"
  local json="$2"
  docker exec "$CONTAINER" sh -c \
    "curl -fsS -XPUT '$ES_URL$path' -H 'Content-Type: application/json' -d '$json' >/dev/null"
}

for i in $(seq 1 40); do
  sku="$(printf 'MV-P%03d' "$i")"
  price=$((9 + i))
  stock=$((20 + (i % 12)))
  put_doc "/maisonverte/products/$sku" "{\"sku\":\"$sku\",\"name\":\"Produit jardin $i\",\"category\":\"jardinerie\",\"price\":$price,\"stock\":$stock}"
done

put_doc "/maisonverte/ops/search-cache-route" '{"service":"cache-srv01","network":"mv-a-core","port":6379,"key":"maisonverte:chain:a:e10:libpq","note":"session cache used by product search workers"}'
