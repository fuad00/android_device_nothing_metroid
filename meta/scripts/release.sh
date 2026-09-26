#!/usr/bin/env bash
# Server: publish the latest metroid build to GitHub Releases of fuad00/nothing_phone_3_lineage.
#   release.sh <tag> "<notes>"
#   ZIP_ONLY=1 release.sh ...   skip the separate images (they are inside the zip payload anyway)
# Assets over GitHub's 2 GiB limit are split into .partNN pieces; SHA256SUMS lists the whole zip
# too, so after joining on the Mac (cat file.zip.part* > file.zip) `shasum -a 256 -c` checks it.
set -euo pipefail
REPO=fuad00/nothing_phone_3_lineage
OUT=/root/oneplus_10_pro_lineage/lineage/out/target/product/metroid
STAGE=/root/nothing_phone_3/release
TAG=$1
NOTES=${2:-}

zip=$(ls -t "$OUT"/lineage-23.2-*-UNOFFICIAL*-metroid.zip | head -1)
z=$(basename "$zip")
rm -rf "${STAGE:?}/$TAG" && mkdir -p "$STAGE/$TAG" && cd "$STAGE/$TAG"
[ "${ZIP_ONLY:-0}" = 1 ] || for f in boot.img init_boot.img vendor_boot.img dtbo.img recovery.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
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
gh release create "$TAG" -R "$REPO" --title "$TAG" --notes "$NOTES" --prerelease ./*
gh release view "$TAG" -R "$REPO" --json url --jq .url
