#!/usr/bin/env bash
# deploiement/00-infra/create-networks.sh
#
# Idempotently creates the six zone networks and nine chain micro-segments
# from deploiement/config/networks.env as external Docker bridge networks,
# with fixed subnets and MaisonVerte labels. A network already present is
# left untouched.
#
# Out of scope (controller ruling on Task 2): per-service private backend
# networks (mv-e3-db for WordPress/MySQL, mv-e11-db for mongo-express/
# MongoDB, mv-e12-db for XXL-JOB/MySQL) are NOT created here. Those are
# declared as ordinary, non-external networks inside each service's own
# compose.yaml (Tasks 3, 5, 6), scoped to that service's own Compose
# project.
#
# This script only calls `docker network inspect` and `docker network
# create`. It never pulls an image, never runs a container and never
# touches the host's package manager.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command docker
mv_load_env "$MV_CONFIG_DIR/networks.env"

# Micro-segment subnets are not pinned in networks.env (only their names
# are: ARCHITECTURE.md documents the six zone /24 subnets but leaves the
# nine internal, never-published chain micro-segments without an assigned
# range). This script pins them here, once, to a dedicated /16 distinct
# from the zone networks (172.30.0.0/16) and from the lab's LAN/WAN
# addressing (192.168.10.0/24, 10.85.4.0/24), so repeated runs stay fully
# idempotent and reproducible.

declare -A NETWORKS=(
  ["$NET_DMZ_NAME"]="$NET_DMZ_SUBNET:zone-dmz"
  ["$NET_SRV_NAME"]="$NET_SRV_SUBNET:zone-srv"
  ["$NET_DATA_NAME"]="$NET_DATA_SUBNET:zone-data"
  ["$NET_USERS_NAME"]="$NET_USERS_SUBNET:zone-users"
  ["$NET_ADMIN_NAME"]="$NET_ADMIN_SUBNET:zone-admin"
  ["$NET_SHOPS_NAME"]="$NET_SHOPS_SUBNET:zone-shops"
  ["$NET_A_EDGE_NAME"]="172.31.10.0/28:chain-a-edge"
  ["$NET_A_CORE_NAME"]="172.31.11.0/28:chain-a-core"
  ["$NET_A_DATA_NAME"]="172.31.12.0/28:chain-a-data"
  ["$NET_B_EDGE_NAME"]="172.31.20.0/28:chain-b-edge"
  ["$NET_B_CORE_NAME"]="172.31.21.0/28:chain-b-core"
  ["$NET_B_DATA_NAME"]="172.31.22.0/28:chain-b-data"
  ["$NET_C_EDGE_NAME"]="172.31.30.0/28:chain-c-edge"
  ["$NET_C_CORE_NAME"]="172.31.31.0/28:chain-c-core"
  ["$NET_C_SPEC_NAME"]="172.31.32.0/28:chain-c-spec"
)

created=0
skipped=0
for name in "${!NETWORKS[@]}"; do
  subnet="${NETWORKS[$name]%%:*}"
  role="${NETWORKS[$name]##*:}"
  if docker network inspect "$name" >/dev/null 2>&1; then
    mv_log "network already present, skipping: $name"
    skipped=$((skipped + 1))
    continue
  fi
  mv_log "creating network: $name (subnet=$subnet, role=$role)"
  docker network create \
    --driver bridge \
    --subnet "$subnet" \
    --label "maisonverte.managed=true" \
    --label "maisonverte.role=$role" \
    "$name" >/dev/null
  created=$((created + 1))
done

mv_log "networks: ${created} created, ${skipped} already present (${#NETWORKS[@]} total expected)"
