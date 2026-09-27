#!/usr/bin/env bash
# Server: publish the latest metroid build to GitHub Releases of fuad00/nothing_phone_3_lineage.
#   release.sh <tag> "<notes>"
#   ZIP_ONLY=1 release.sh ...   skip the separate images (they are inside the zip payload anyway)
#   INCREMENTAL_FROM=<tag> ...  also build an incremental OTA from that release; it is uploaded
#                               first (tens of MB instead of 4 GB), the full zip follows as a
#                               fallback. It installs only over exactly that release: recovery
#                               refuses it on any other build, without changing anything.
# Every release keeps its target-files in $TF_DIR/<tag>.zip as the base for the next incremental
# (the last $TF_KEEP are kept). Assets over GitHub's 2 GiB limit are split into .partNN pieces;
# SHA256SUMS lists the whole zip too, so after joining on the Mac (cat file.zip.part* > file.zip)
# `shasum -a 256 -c` checks it.
set -euo pipefail
REPO=fuad00/nothing_phone_3_lineage
TOP=/root/nothing_phone_3/lineage
OUT=$TOP/out/target/product/metroid
STAGE=/root/nothing_phone_3/release
TF_DIR=/root/nothing_phone_3/target-files
TF_KEEP=5
TAG=$1
NOTES=${2:-}

zip=$(ls -t "$OUT"/lineage-23.2-*-UNOFFICIAL*-metroid.zip | head -1)
z=$(basename "$zip")
# the build leaves target-files as a directory only; zip it (soong_zip, ~30 s for 14 GB)
tf=$OUT/obj/PACKAGING/target_files_intermediates/lineage_metroid-target_files
[ -d "$tf" ] || { echo "no target-files directory $tf" >&2; exit 2; }
mkdir -p "$TF_DIR"
"$TOP/out/host/linux-x86/bin/soong_zip" -d -o "$TF_DIR/$TAG.zip" -C "$tf" -D "$tf"
ls -t "$TF_DIR"/*.zip | tail -n +$((TF_KEEP + 1)) | xargs -r rm -f

rm -rf "${STAGE:?}/$TAG" && mkdir -p "$STAGE/$TAG" && cd "$STAGE/$TAG"

inc=""
if [ -n "${INCREMENTAL_FROM:-}" ]; then
  base="$TF_DIR/$INCREMENTAL_FROM.zip"
  [ -f "$base" ] || { echo "no target-files for $INCREMENTAL_FROM in $TF_DIR" >&2; exit 2; }
  inc="lineage-23.2-metroid-incremental-$INCREMENTAL_FROM-to-$TAG.zip"
  # same default test key as the full OTA, so the Lineage recovery accepts both
  (cd "$TOP" && out/host/linux-x86/bin/ota_from_target_files -i "$base" "$TF_DIR/$TAG.zip" \
      "$STAGE/$TAG/$inc") > ota-incremental.log 2>&1 || { tail -20 ota-incremental.log >&2; exit 3; }
  rm ota-incremental.log
fi

[ "${ZIP_ONLY:-0}" = 1 ] || for f in boot.img init_boot.img vendor_boot.img dtbo.img recovery.img pvmfw.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
  [ -f "$OUT/$f" ] && ln -f "$OUT/$f" .
done
ln -f "$zip" .
sha256sum ./* > SHA256SUMS
limit=$((2000 * 1024 * 1024))
if [ "$(stat -c %s "$z")" -gt $limit ]; then
  split -b 1900M -d --additional-suffix= "$z" "$z.part"
  rm "$z"
  sha256sum ./"$z".part* >> SHA256SUMS
fi

if [ -n "$inc" ]; then
  # the small package first, so it can be downloaded while the full zip uploads
  NOTES="$NOTES

Incremental: $inc ($(du -h "$inc" | cut -f1)), installs only over $INCREMENTAL_FROM. The full zip parts are the fallback."
  gh release create "$TAG" -R "$REPO" --title "$TAG" --notes "$NOTES" --prerelease "./$inc" ./SHA256SUMS
  gh release view "$TAG" -R "$REPO" --json url --jq .url
  find . -maxdepth 1 -type f ! -name "$inc" ! -name SHA256SUMS -print0 | xargs -0 -r gh release upload "$TAG" -R "$REPO"
else
  gh release create "$TAG" -R "$REPO" --title "$TAG" --notes "$NOTES" --prerelease ./*
  gh release view "$TAG" -R "$REPO" --json url --jq .url
fi
