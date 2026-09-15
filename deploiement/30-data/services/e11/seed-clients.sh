#!/usr/bin/env bash
# Idempotently seed the E11 MongoDB clients database with loyalty data.
set -Eeuo pipefail

: "${MV_E11_FLAG:?MV_E11_FLAG is required}"

js_file="$(mktemp)"
trap 'rm -f "$js_file"' EXIT

cat >"$js_file" <<JS
var flag = ${MV_E11_FLAG@Q};
db = db.getSiblingDB('maisonverte_clients');
db.clients.drop();
var tiers = ['graine', 'feuille', 'branche', 'canopee'];
var cities = ['Lyon', 'Nantes', 'Paris', 'Rennes', 'Tours', 'Bordeaux'];
var docs = [];
for (var i = 1; i <= 30; i++) {
  docs.push({
    client_id: 'CLI-' + ('000' + i).slice(-3),
    name: 'Client MaisonVerte ' + i,
    city: cities[(i - 1) % cities.length],
    loyalty: {
      tier: tiers[(i - 1) % tiers.length],
      points: 120 + (i * 37),
      enrolled_at: ISODate('2026-06-' + ('0' + (((i - 1) % 28) + 1)).slice(-2) + 'T08:00:00Z')
    },
    last_order_ref: 'CMD-2026-' + ('0000' + (4100 + i)).slice(-4),
    marketing_opt_in: (i % 3 !== 0)
  });
}
db.clients.insertMany(docs);
db.loyalty_program.drop();
db.loyalty_program.insertMany([
  { tier: 'graine', min_points: 0, benefit: 'atelier saisonnier' },
  { tier: 'feuille', min_points: 500, benefit: 'livraison offerte mensuelle' },
  { tier: 'branche', min_points: 1000, benefit: 'remise panier bio 8%' },
  { tier: 'canopee', min_points: 1800, benefit: 'acces ventes privees' }
]);
db.flags.update(
  { service: 'E11' },
  { service: 'E11', purpose: 'clients flag', value: flag, stored_at: new Date() },
  { upsert: true }
);
JS

docker cp "$js_file" clients-data01-mongo:/tmp/mv-seed-clients.js
docker exec clients-data01-mongo mongo --quiet /tmp/mv-seed-clients.js >/dev/null
