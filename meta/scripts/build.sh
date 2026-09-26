#!/usr/bin/env bash
# Build LineageOS 23.2 for metroid on the build server (own tree, see meta/manifests/metroid.xml).
#   scripts/build.sh [target] [extra mka args]   target: bacon (default) | bootimage | vendorbootimage | ...
# Env: VARIANT=userdebug (default), DEBUG=1 (default) -> WITH_ADB_INSECURE=true
# Log: /root/nothing_phone_3/logs/build_<date>_<target>.log
set -o pipefail  # no -u: build/envsetup.sh uses unset variables

ROOT=/root/nothing_phone_3
TOP=${TOP:-$ROOT/lineage}
TARGET=${1:-bacon}
shift || true
VARIANT=${VARIANT:-userdebug}
LOG=$ROOT/logs/build_$(date +%Y%m%d_%H%M)_${TARGET}.log

# One build at a time on the server (the OnePlus tree builds here too)
if pgrep -af "[s]oong_ui" >/dev/null; then
  echo "another build is running:"; pgrep -af "[s]oong_ui"; exit 2
fi

cd "$TOP" || exit 1
# Generated inputs: the source-built kernel and the blobs extracted from stock
DEV=device/nothing/metroid
[ -f $DEV/kernel/out/Image ] || { echo "no $DEV/kernel/out: run $DEV/meta/kernel/stage-kernel.sh"; exit 2; }
[ -f vendor/nothing/metroid/metroid-vendor.mk ] || { echo "no vendor/nothing/metroid: run $DEV/extract-files.py"; exit 2; }
ln -sfn "$LOG" "$ROOT/logs/current_build.log"
# Own ccache: do not evict the wly entries from the shared one
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR=$ROOT/ccache
mkdir -p "$CCACHE_DIR"; ccache -M 40G >/dev/null
# Build identity (zip name, ro.lineage.version, ro.build.user/host); the kernel identity
# (fuad00@fuad00-lineage, -fuad00) comes from the build/kernel fork of the Kleaf workspace
export TARGET_UNOFFICIAL_BUILD_ID=fuad00
export BUILD_USERNAME=fuad00 BUILD_HOSTNAME=fuad00-lineage
[ "${DEBUG:-1}" = 1 ] && export WITH_ADB_INSECURE=true
# Private branding only when the tree opts in (see docs); off until the first stable boot
[ -n "$BRANDING" ] && [ -f "$TOP/vendor/smk/config/branding.mk" ] && export CUSTOM_BRANDING_DIR=vendor/smk
export LC_ALL=C.UTF-8

{
  echo "BUILD START $(date) target=$TARGET variant=$VARIANT adb_insecure=${WITH_ADB_INSECURE:-false}"
  # shellcheck disable=SC1091
  source build/envsetup.sh
  breakfast metroid "$VARIANT"
  mka "$TARGET" "$@"
  rc=$?
  echo "BUILD END $(date) target=$TARGET rc=$rc"
  exit $rc
} > "$LOG" 2>&1
rc=$?
echo "$LOG rc=$rc"
exit $rc
