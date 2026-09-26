#!/usr/bin/env bash
# Put the staged kernel (stage-kernel.sh) into an installed build's images, to test the kernel
# alone without rebuilding Android: boot (Image), vendor_boot (ramdisk modules + dtb),
# vendor_dlkm and system_dlkm (modules). dtbo is not touched. Every module the base images
# carry is replaced by ours by name; module metadata (modules.dep/alias/softdep) is regenerated,
# load lists and blocklists are kept. Needs root (loop mounts the dlkm images).
#   make-test-images.sh <base-image-dir> [stage-dir] [out-dir]
set -euo pipefail
BASE="$(cd "${1:?base image dir (boot.img vendor_boot.img vendor_dlkm.img system_dlkm.img)}" && pwd)"
STAGE="${2:-/root/nothing_phone_3/kernel-out}"
OUT="${3:-/root/nothing_phone_3/test-images}"
LINEAGE="${LINEAGE:-/root/oneplus_10_pro_lineage/lineage}"
T="$LINEAGE/out/host/linux-x86/bin"
TESTKEY="$LINEAGE/external/avb/test/data/testkey_rsa4096.pem"
WORK="$OUT/work"

rm -rf "$OUT" && mkdir -p "$WORK"

module_src() {  # <name.ko> -> path of our build of it
    if [[ -f "$STAGE/gki/$1" ]]; then echo "$STAGE/gki/$1"
    elif [[ -f "$STAGE/vendor/$1" ]]; then echo "$STAGE/vendor/$1"
    else return 1; fi
}

# Regenerate modules.dep/alias/softdep the way stock does: depmod sees only the modules that
# are on the device when this directory is used (the directory itself, plus system_dlkm's GKI
# modules for vendor_dlkm). Dependencies on first-stage ramdisk modules are therefore left out
# (they are loaded already), and nothing points at a file the partition does not have. Paths are
# absolute device paths; GKI modules live in /system/lib/modules (logix727 lesson: wrong paths
# leave cfg80211/wlan unloadable).
regen_depmod() {  # <dir> <prefix> [with-gki]
    local dir="$1" prefix="$2" with_gki="${3:-}" tmp
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/lib/modules/0.0"
    cp "$dir"/*.ko "$tmp/lib/modules/0.0/"
    [[ -z "$with_gki" ]] || cp -n "$STAGE"/gki/*.ko "$tmp/lib/modules/0.0/"
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

replace_modules() {  # <modules dir>
    local n src
    for f in "$1"/*.ko; do
        n="$(basename "$f")"
        src="$(module_src "$n")" || { echo "!! no build of $n" >&2; return 1; }
        cat "$src" > "$f"   # overwrite in place: keeps the inode, owner and SELinux label
    done
}

# The base image's AVB properties must be carried over: the bootloader hands
# com.android.build.boot.security_patch to KeyMint as the boot patch level, and without it
# KeyMint refuses every key made before (vold: decryptWithKeystoreKey failed ->
# init_user0_failed).
avb_props() {  # <image> -> --prop k:v ...
    "$T/avbtool" info_image --image "$1" |
        sed -n "s/^ *Prop: \(.*\) -> '\(.*\)'\$/--prop\n\1:\2/p"
}

echo ":: boot"
mapfile -t props < <(avb_props "$BASE/boot.img")
mapfile -t args < <(xargs -n1 <<< "$("$T/unpack_bootimg" --boot_img "$BASE/boot.img" --out "$WORK/boot" --format mkbootimg)")
for i in "${!args[@]}"; do [[ "${args[$i]}" == --kernel ]] && args[$((i + 1))]="$STAGE/Image"; done
"$T/mkbootimg" "${args[@]}" --output "$OUT/boot.img"
"$T/avbtool" add_hash_footer --image "$OUT/boot.img" --partition_name boot \
    --partition_size "$(stat -c%s "$BASE/boot.img")" --key "$TESTKEY" --algorithm SHA256_RSA4096 \
    --rollback_index "$("$T/avbtool" info_image --image "$BASE/boot.img" | awk '/Rollback Index:/{print $3; exit}')" \
    "${props[@]}"

echo ":: vendor_boot"
mapfile -t args < <(xargs -n1 <<< "$("$T/unpack_bootimg" --boot_img "$BASE/vendor_boot.img" --out "$WORK/vboot" --format mkbootimg)")
[[ $(printf '%s\n' "${args[@]}" | grep -c '^--vendor_ramdisk_fragment$') == 1 ]] \
    || { echo "!! expected exactly one vendor ramdisk fragment" >&2; exit 1; }
R="$WORK/vramdisk"; mkdir -p "$R"
frag=""
for i in "${!args[@]}"; do
    case "${args[$i]}" in
        --vendor_ramdisk_fragment) frag="${args[$((i + 1))]}"; args[$((i + 1))]="$WORK/vramdisk.lz4" ;;
        --dtb) args[$((i + 1))]="$STAGE/dtb.img" ;;
    esac
done
(cd "$R" && lz4 -dc "$frag" | cpio -idm --quiet)
replace_modules "$R/lib/modules"
regen_depmod "$R/lib/modules" /lib/modules
(cd "$R" && find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | lz4 -l -12 --favor-decSpeed > "$WORK/vramdisk.lz4")
"$T/mkbootimg" "${args[@]}" --vendor_boot "$OUT/vendor_boot.img"
mapfile -t props < <(avb_props "$BASE/vendor_boot.img")
"$T/avbtool" add_hash_footer --image "$OUT/vendor_boot.img" --partition_name vendor_boot \
    --partition_size "$(stat -c%s "$BASE/vendor_boot.img")" "${props[@]}"

dlkm() {  # <name> <prefix> <with-gki: yes|""> [modules to drop]
    local name="$1" prefix="$2" with_gki="$3"; shift 3
    local img="$WORK/$name.img" mnt="$WORK/$name.mnt"
    echo ":: $name"
    cp "$BASE/$name.img" "$img"
    "$T/avbtool" erase_footer --image "$img" 2>/dev/null || true
    e2fsck -fy "$img" >/dev/null || true
    resize2fs -f "$img" 1G >/dev/null
    mkdir -p "$mnt" && mount -o loop "$img" "$mnt"
    trap "umount '$mnt' 2>/dev/null || true" EXIT
    for n in "$@"; do
        rm -f "$mnt/lib/modules/$n"
        sed -i "/^\(.*\/\)\?${n//./\\.}\$/d" "$mnt/lib/modules/modules.load"
    done
    replace_modules "$mnt/lib/modules"
    regen_depmod "$mnt/lib/modules" "$prefix" "$with_gki"
    umount "$mnt"; trap - EXIT
    e2fsck -fy "$img" >/dev/null || [[ $? -le 1 ]]
    resize2fs -M "$img" >/dev/null
    local blocks; blocks=$(dumpe2fs -h "$img" 2>/dev/null | awk '/^Block count:/{print $3}')
    truncate -s $((blocks * 4096)) "$img"
    mv "$img" "$OUT/$name.img"
}
dlkm vendor_dlkm /vendor/lib/modules yes
# tls.ko: a stale 6.6.102 GKI module shipped by stock; android15-6.6 GKI builds TLS in no form
dlkm system_dlkm /system/lib/modules "" tls.ko

rm -rf "$WORK"
(cd "$OUT" && sha256sum *.img > SHA256SUMS && cp "$STAGE/build-info.txt" . && ls -la)
