#!/usr/bin/env bash
# deploiement/90-orchestration/prepare-offline-bundle.sh
#
# CONNECTED_HOST_ONLY: this script runs exclusively on a machine that has
# Internet/registry access, NEVER on the lab host. It exports every image
# already present locally (per deploiement/config/images.lock) into a
# single maisonverte-images.tar bundle plus a .sha256 checksum, for
# transfer to the lab via removable media and import there via
# 00-infra/import-offline-images.sh (the only import path in the lab).
#
# It never calls `docker pull`: every image must already be present
# locally, pulled beforehand by the operator through their own normal
# (connected) channel — this script only packages what is already there.

CONNECTED_HOST_ONLY=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command docker
mv_require_command sha256sum

# Refuse to run on a host that looks like it is on the lab network (LAN
# 192.168.10.0/24, or the OPNsense WAN publication 10.85.4.0/24): this
# script must only ever run on the connected build host, never inside the
# isolated lab.
LAB_PATTERNS=('192\.168\.10\.' '10\.85\.4\.')
if command -v ip >/dev/null 2>&1; then
  host_addrs="$(ip -4 -o addr show 2>/dev/null | awk '{print $4}')"
  for pattern in "${LAB_PATTERNS[@]}"; do
    if grep -qE "$pattern" <<<"$host_addrs"; then
      mv_die "refusing to run on a host with a lab address (matched: $pattern) — CONNECTED_HOST_ONLY=1"
    fi
  done
fi

images_lock="$MV_CONFIG_DIR/images.lock"
mv_require_file "$images_lock"

mapfile -t images < <(grep -Ev '^[[:space:]]*(#|$)' "$images_lock")
if [[ "${#images[@]}" -eq 0 ]]; then
  mv_die "images.lock has no pinned images"
fi

missing=0
for image in "${images[@]}"; do
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    mv_log "MISSING locally (this script never pulls — fetch it first via your own channel): $image"
    missing=$((missing + 1))
  fi
done
if ((missing > 0)); then
  mv_die "${missing} image(s) missing locally — this script never runs docker pull"
fi

OUT_DIR="$(mv_state_dir)/offline-bundle"
mkdir -p "$OUT_DIR"
BUNDLE_FILE="$OUT_DIR/maisonverte-images.tar"
SUM_FILE="${BUNDLE_FILE}.sha256"

mv_log "exporting ${#images[@]} image(s) already present locally into $BUNDLE_FILE"
docker save --output "$BUNDLE_FILE" "${images[@]}"

(cd "$OUT_DIR" && sha256sum "$(basename -- "$BUNDLE_FILE")" >"$(basename -- "$SUM_FILE")")

mv_log "bundle written: $BUNDLE_FILE"
mv_log "checksum written: $SUM_FILE"
