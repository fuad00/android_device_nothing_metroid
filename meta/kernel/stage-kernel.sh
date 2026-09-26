#!/usr/bin/env bash
# Collect everything the metroid kernel build produced into one flat, reproducible directory:
#   Image              GKI kernel built from //common (fuad00 identity, see build/kernel fork)
#   gki/*.ko           GKI modules for system_dlkm, signed by this build (never stripped: that
#                      would drop the appended signature)
#   vendor/*.ko        msm-kernel + techpack + ST modules, --strip-debug'ed (stock ships them
#                      unsigned and stripped as well)
#   dtb.img dtbo.img   tuna base DTB with SoC overlays merged, and the board overlays
#   build-info.txt     kernel release and the commits everything came from
# Module indexing, stripping and the DTB layout follow logix727's stage_kernel_artifacts.sh
# (Apache-2.0), minus its prebuilt GKI Image, prebuilt system_dlkm and stock NFC modules.
#   stage-kernel.sh [kernel-workspace] [out-dir]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
KWS="$(cd "${1:-/root/nothing_phone_3/kernelws}" && pwd)"
OUT="${2:-/root/nothing_phone_3/kernel-out}"
STRIP="$KWS/prebuilts/clang/host/linux-x86/clang-r510928/bin/llvm-strip"
MKDTIMG="${MKDTIMG:-/root/oneplus_10_pro_lineage/lineage/system/libufdt/utils/src/mkdtboimg.py}"
KOUT="$KWS/bazel-bin/msm-kernel/sun_perf"
GKI="$KWS/bazel-bin/common/kernel_aarch64"

[[ -f "$GKI/Image" && -d "$KOUT" ]] || { echo "!! build the kernel first (build-kernel.sh)" >&2; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT/gki" "$OUT/vendor" "$OUT/tmp"

cp "$GKI/Image" "$OUT/Image"
release=$(strings "$OUT/Image" | sed -n 's/^Linux version \([^ ]*\) .*/\1/p' | head -1)

# GKI modules: the signed, installed copies from modules_install
tar -xzf "$GKI/modules_staging_dir.tar.gz" -C "$OUT/tmp"
find "$OUT/tmp" -name '*.ko' -exec cp {} "$OUT/gki/" \;
rm -rf "$OUT/tmp"

# Vendor modules. unstripped/ and staging/ hold byte-identical copies of the same modules;
# anything that differs is reported rather than silently picked.
declare -A KO
while IFS= read -r f; do
    n="$(basename "$f")"
    [[ -e "$OUT/gki/$n" ]] && continue
    if [[ -z "${KO[$n]:-}" ]]; then
        KO["$n"]="$f"
    elif ! cmp -s "${KO[$n]}" "$f"; then
        echo "!! two different builds of $n: ${KO[$n]} $f" >&2; exit 1
    fi
done < <(find "$KOUT" "$KWS/bazel-bin/vendor" "$KWS/bazel-bin/nothing-modules" -name '*.ko' \
              -not -path '*/unstripped/*' -not -path '*/staging/*' -not -path '*runfiles*' | sort)
for n in "${!KO[@]}"; do
    # --strip-debug, not --strip-all: .modinfo and __versions must survive
    "$STRIP" --strip-debug "${KO[$n]}" -o "$OUT/vendor/$n"
done

MKDTIMG="$MKDTIMG" "$HERE/build_tuna_dtb.sh" "$KWS/msm-kernel" "$KOUT" "$OUT/dt" > "$OUT/dt.log"
# dtb.img = merged tuna.dtb + the sibling tuna7/tunap variants, as the stock image carries
cat "$OUT/dt/tuna.dtb" "$KOUT/tuna7.dtb" "$KOUT/tunap.dtb" > "$OUT/dtb.img"
cp "$OUT/dt/dtbo.img" "$OUT/dtbo.img"

{
    echo "release $release"
    for p in common msm-kernel nothing-modules build/kernel; do
        echo "$p $(git -C "$KWS/$p" log -1 --format='%H %s')"
    done
} > "$OUT/build-info.txt"
echo ":: $OUT: $release, $(ls "$OUT/gki" | wc -l) GKI + $(ls "$OUT/vendor" | wc -l) vendor modules," \
     "dtb $(stat -c%s "$OUT/dtb.img") B, dtbo $(stat -c%s "$OUT/dtbo.img") B"
