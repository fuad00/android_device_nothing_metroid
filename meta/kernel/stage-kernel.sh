#!/usr/bin/env bash
# Stage the source-built metroid kernel (build-kernel.sh) into the device tree's kernel/out/,
# the layout BoardConfig.mk, device.mk and dlkm_modules.mk consume. Nothing here is prebuilt:
#   Image                    GKI kernel from //common, fuad00 identity (build/kernel fork)
#   dtb.img dtbo.img         tuna DTB with SoC overlays merged + board overlays (build_tuna_dtb.sh)
#   kernel-headers.tar.gz    techpack UAPI headers for userspace HALs, from msm-kernel
#   vendor_ramdisk/*.ko      closure of modules.load.vendor_boot + modules.load.recovery
#   vendor_dlkm/             kernel/modules.vendor_dlkm + load lists, regenerated modules.dep
#   system_dlkm/             every GKI module, signed by this build (never stripped)
#   all/{gki,vendor}/        every module the build produced (make-test-images.sh uses these)
#   build-info.txt           kernel release and the commits everything came from
# The module layout, stripping and dependency handling follow logix727's
# kernel/stage_kernel_artifacts.sh (Apache-2.0), minus its prebuilt GKI Image, prebuilt
# system_dlkm and stock NFC modules.
#   stage-kernel.sh [kernel-workspace] [out-dir]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEVICE="$(cd "$HERE/../.." && pwd)"
KWS="$(cd "${1:-/root/nothing_phone_3/kernelws}" && pwd)"
OUT="${2:-$DEVICE/kernel/out}"
STRIP="$KWS/prebuilts/clang/host/linux-x86/clang-r510928/bin/llvm-strip"
MKDTIMG="${MKDTIMG:-$DEVICE/../../../system/libufdt/utils/src/mkdtboimg.py}"
[[ -f "$MKDTIMG" ]] || MKDTIMG=/root/oneplus_10_pro_lineage/lineage/system/libufdt/utils/src/mkdtboimg.py
KOUT="$KWS/bazel-bin/msm-kernel/sun_perf"
GKI="$KWS/bazel-bin/common/kernel_aarch64"

[[ -f "$GKI/Image" && -d "$KOUT" ]] || { echo "!! build the kernel first (build-kernel.sh)" >&2; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT"/{all/gki,all/vendor,vendor_ramdisk,vendor_dlkm,system_dlkm,tmp}

cp "$GKI/Image" "$OUT/Image"
release=$(strings "$OUT/Image" | sed -n 's/^Linux version \([^ ]*\) .*/\1/p' | head -1)

# GKI modules: the signed, installed copies from modules_install
tar -xzf "$GKI/modules_staging_dir.tar.gz" -C "$OUT/tmp"
find "$OUT/tmp" -name '*.ko' -exec cp {} "$OUT/all/gki/" \;
rm -rf "$OUT/tmp"

# Vendor modules. unstripped/ and staging/ hold byte-identical copies of the same modules;
# anything that differs is reported rather than silently picked.
declare -A KO
while IFS= read -r f; do
    n="$(basename "$f")"
    [[ -e "$OUT/all/gki/$n" ]] && continue
    if [[ -z "${KO[$n]:-}" ]]; then
        KO["$n"]="$f"
    elif ! cmp -s "${KO[$n]}" "$f"; then
        echo "!! two different builds of $n: ${KO[$n]} $f" >&2; exit 1
    fi
done < <(find "$KOUT" "$KWS/bazel-bin/vendor" "$KWS/bazel-bin/nothing-modules" -name '*.ko' \
              -not -path '*/unstripped/*' -not -path '*/staging/*' -not -path '*runfiles*' | sort)
for n in "${!KO[@]}"; do
    # --strip-debug, not --strip-all: .modinfo and __versions must survive
    "$STRIP" --strip-debug "${KO[$n]}" -o "$OUT/all/vendor/$n"
done

module() {  # <name.ko> -> our build of it
    if [[ -f "$OUT/all/gki/$1" ]]; then echo "$OUT/all/gki/$1"
    elif [[ -f "$OUT/all/vendor/$1" ]]; then echo "$OUT/all/vendor/$1"
    else echo "!! no build of $1" >&2; return 1; fi
}

# depmod over <dir> [+ GKI modules], rewritten to absolute device paths the way stock does:
# GKI modules under /system/lib/modules, the rest under <prefix>. depmod only sees modules
# that are on the device when <dir> is used, so nothing points at a file that is not there
# (logix727 lesson: bare names or wrong paths leave rfkill -> cfg80211 -> wlan unloadable).
regen_depmod() {  # <dir> <prefix> [with-gki]
    local dir="$1" prefix="$2" with_gki="${3:-}" tmp
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/lib/modules/0.0"
    cp "$dir"/*.ko "$tmp/lib/modules/0.0/"
    [[ -z "$with_gki" ]] || cp -n "$OUT"/all/gki/*.ko "$tmp/lib/modules/0.0/"
    depmod -b "$tmp" 0.0 2>/dev/null
    python3 - "$tmp/lib/modules/0.0" "$dir" "$prefix" <<'PY'
import os, sys
src, dst, prefix = sys.argv[1:]
here = {f for f in os.listdir(dst) if f.endswith(".ko")}
path = lambda n: (prefix if n in here else "/system/lib/modules") + "/" + n
with open(os.path.join(dst, "modules.dep"), "w") as out:
    for line in open(os.path.join(src, "modules.dep")):
        mod, deps = line.split(":", 1)
        d = [path(os.path.basename(x)) for x in deps.split()]
        out.write(path(os.path.basename(mod)) + ":" + "".join(" " + x for x in d) + "\n")
for name in ("modules.alias", "modules.softdep"):
    with open(os.path.join(dst, name), "w") as out:
        out.writelines(l for l in open(os.path.join(src, name)) if not l.startswith("#"))
PY
    rm -rf "$tmp"
}

# vendor_dlkm: the stock module set and its load lists
while read -r n; do
    [[ -n "$n" ]] && cp "$(module "$n")" "$OUT/vendor_dlkm/$n"
done < "$DEVICE/kernel/modules.vendor_dlkm"
cp "$DEVICE"/kernel/vendor_dlkm-meta/modules.{load,load.recovery,blocklist} "$OUT/vendor_dlkm/"
regen_depmod "$OUT/vendor_dlkm" /vendor/lib/modules yes

# system_dlkm: every GKI module of this build; tipc must be boot-loaded for Qualcomm data
# (DSI needs AF_TIPC, logix727 lesson), everything else loads on demand
cp "$OUT"/all/gki/*.ko "$OUT/system_dlkm/"
echo tipc.ko > "$OUT/system_dlkm/modules.load"
regen_depmod "$OUT/system_dlkm" /system/lib/modules

# vendor_boot ramdisk: the dependency closure of both load lists; the platform build runs its
# own depmod over these. cfg80211, mac80211 and tz_log_dlkm are not reachable from the lists
# but ship in the stock ramdisk.
python3 - "$OUT" "$DEVICE" <<'PY'
import os, subprocess, sys, tempfile, shutil
out, device = sys.argv[1:]
pool = {}
for d in ("all/vendor", "all/gki"):
    for f in os.listdir(os.path.join(out, d)):
        pool.setdefault(f, os.path.join(out, d, f))
tmp = tempfile.mkdtemp()
mods = os.path.join(tmp, "lib/modules/0.0")
os.makedirs(mods)
for f, p in pool.items():
    shutil.copy(p, mods)
subprocess.run(["depmod", "-b", tmp, "0.0"], check=True, stderr=subprocess.DEVNULL)
deps = {}
for line in open(os.path.join(mods, "modules.dep")):
    m, rest = line.split(":", 1)
    deps[os.path.basename(m)] = [os.path.basename(d) for d in rest.split()]
shutil.rmtree(tmp)
want, seen = [], set()
def add(m):
    if m in seen:
        return
    if m not in pool:
        raise SystemExit(f"missing vendor ramdisk module: {m}")
    seen.add(m)
    for d in deps.get(m, []):
        add(d)
    want.append(m)
for extra in ("cfg80211.ko", "mac80211.ko", "tz_log_dlkm.ko"):
    add(extra)
for name in ("modules.load.vendor_boot", "modules.load.recovery"):
    for line in open(os.path.join(device, name)):
        if line.strip():
            add(line.strip())
for m in want:
    shutil.copy(pool[m], os.path.join(out, "vendor_ramdisk", m))
print(f":: vendor_ramdisk: {len(want)} modules")
PY

# Device tree blobs
MKDTIMG="$MKDTIMG" "$HERE/build_tuna_dtb.sh" "$KWS/msm-kernel" "$KOUT" "$OUT/dt" > "$OUT/dt.log"
# dtb.img = merged tuna.dtb + the sibling tuna7/tunap variants, as the stock image carries
cat "$OUT/dt/tuna.dtb" "$KOUT/tuna7.dtb" "$KOUT/tunap.dtb" > "$OUT/dtb.img"
cp "$OUT/dt/dtbo.img" "$OUT/dtbo.img"

# Techpack UAPI headers for the HALs (TARGET_PREBUILT_KERNEL_HEADERS)
"$HERE/generate-kernel-headers.sh" "$KWS/msm-kernel" "$OUT/kernel-headers.tar.gz" > /dev/null

{
    echo "release $release"
    for p in common msm-kernel nothing-modules build/kernel; do
        echo "$p $(git -C "$KWS/$p" log -1 --format='%H %s')"
    done
} > "$OUT/build-info.txt"
echo ":: $OUT: $release; vendor_dlkm $(ls "$OUT"/vendor_dlkm/*.ko | wc -l)," \
     "system_dlkm $(ls "$OUT"/system_dlkm/*.ko | wc -l), vendor_ramdisk $(ls "$OUT"/vendor_ramdisk | wc -l)"
