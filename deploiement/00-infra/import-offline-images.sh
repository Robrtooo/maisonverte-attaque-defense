#!/usr/bin/env bash
# deploiement/00-infra/import-offline-images.sh
#
# The only image-import path allowed inside the lab. Verifies the SHA-256
# checksum of the offline bundle produced by
# 90-orchestration/prepare-offline-bundle.sh BEFORE ever calling `docker
# load` on it, then confirms every pinned reference in images.lock is
# present locally. Never calls `docker pull`, a package manager or any
# network download tool.
#
# Usage: import-offline-images.sh [path/to/maisonverte-images.tar]
# Defaults to deploiement/state/offline-bundle/maisonverte-images.tar.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

mv_require_command docker
mv_require_command sha256sum

BUNDLE_FILE="${1:-$(mv_state_dir)/offline-bundle/maisonverte-images.tar}"
SUM_FILE="${BUNDLE_FILE}.sha256"

mv_require_file "$BUNDLE_FILE"
mv_require_file "$SUM_FILE"

bundle_dir="$(cd -- "$(dirname -- "$BUNDLE_FILE")" >/dev/null 2>&1 && pwd)"
bundle_base="$(basename -- "$BUNDLE_FILE")"
sum_base="$(basename -- "$SUM_FILE")"

mv_log "verifying checksum before any docker load: $sum_base"
if ! (cd "$bundle_dir" && sha256sum -c "$sum_base" >/dev/null 2>&1); then
  mv_die "checksum verification failed for $BUNDLE_FILE — refusing to docker load an unverified bundle"
fi
mv_log "checksum OK: $bundle_base"

mv_log "loading images from verified bundle (docker load, never docker pull): $BUNDLE_FILE"
docker load --input "$BUNDLE_FILE" >/dev/null

images_lock="$MV_CONFIG_DIR/images.lock"
mv_require_file "$images_lock"
missing=0
while IFS= read -r image; do
  [[ -z "$image" || "$image" =~ ^# ]] && continue
  if docker image inspect "$image" >/dev/null 2>&1; then
    mv_log "OK: $image"
  else
    mv_log "MISSING after import: $image"
    missing=$((missing + 1))
  fi
done <"$images_lock"

if ((missing > 0)); then
  mv_die "${missing} pinned image(s) still missing after import"
fi

mv_log "import complete: all pinned images present"
