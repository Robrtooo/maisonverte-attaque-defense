#!/usr/bin/env bash
# Seed E10 with deterministic catalog and orders using the image psql client.
set -Eeuo pipefail

CONTAINER="${CONTAINER:-catalog-data01}"
DB_USER="${E10_DB_USER:-mv_catalog_admin}"
DB_NAME="${E10_DB_NAME:-maisonverte}"

sql_file="$(mktemp)"
trap 'rm -f "$sql_file"' EXIT

{
  echo "TRUNCATE orders, products RESTART IDENTITY;"
  for i in $(seq 1 40); do
    sku="$(printf 'MV-P%03d' "$i")"
    price=$((9 + i))
    stock=$((20 + (i % 12)))
    printf "INSERT INTO products(sku,name,category,price,stock) VALUES ('%s','Produit jardin %s','jardinerie',%s,%s);\n" "$sku" "$i" "$price" "$stock"
  done
  for i in $(seq 1 60); do
    sku="$(printf 'MV-P%03d' $(( ((i - 1) % 40) + 1 )))"
    oid="$(printf 'CMD-%03d' "$i")"
    day=$(( ((i - 1) % 28) + 1 ))
    month=$(( ((i - 1) % 3) + 1 ))
    status_index=$(( i % 5 ))
    case "$status_index" in
      0) status="payee" ;;
      1) status="preparee" ;;
      2) status="expediee" ;;
      3) status="retour" ;;
      *) status="litige" ;;
    esac
    printf "INSERT INTO orders(order_id,sku,quantity,status,created_at) VALUES ('%s','%s',%s,'%s','2026-%02d-%02d');\n" "$oid" "$sku" $(( (i % 4) + 1 )) "$status" "$month" "$day"
  done
} >"$sql_file"

docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <"$sql_file" >/dev/null
