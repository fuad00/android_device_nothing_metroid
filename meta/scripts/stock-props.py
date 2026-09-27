#!/usr/bin/env python3
# Print the stock properties our build does not set, grouped by the device tree prop file they
# belong in, with the ones we deliberately leave out filtered by SKIP. Stock HALs read many of
# them (feature flags, brightness tables, audio, Bluetooth offload, data, NFC), and the
# logix727 prop files only carried part of the list.
#   stock-props.py <stock dump> <out/target/product/metroid>
# Review the output, then paste each block at the end of the named prop file.
import os, re, sys

stock, out = sys.argv[1:]

# stock prop file -> device tree prop file
TARGETS = {
    "vendor/build.prop": "vendor.prop",
    "odm/etc/build.prop": "odm.prop",
    "system/build.prop": "system.prop",
    "system_ext/etc/build.prop": "system_ext.prop",
    "product/etc/build.prop": "product.prop",
}

SKIP = [re.compile(p) for p in (
    # build identity, set by the build system
    r"^ro\.(build|product|system|bootimage|system_ext|odm\.build|vendor\.build|vendor_dlkm|"
    r"system_dlkm|odm_dlkm|bionic)\.", r"^ro\.vendor\.boot_security_patch$",
    r"^ro\.(odm|vendor)\.product\.cpu\.", r"^ro\.nothing\.", r"^ro\.oem_unlock_supported$",
    # Virtual A/B, storage and zram: build flags and fstab own these
    r"^ro\.virtual_ab\.", r"^external_storage\.", r"^persist\.sys\.zram",
    # Nothing OS logging, crash upload, debug policy and its own services
    r"^persist\.(service|sys)\.(apklogfs|kmsglogfs|eventlogfs|radiologfs|uploadlog|crashlog|"
    r"build\.mp|event\.detect|custom\.event|minidump)", r"^ro\.logkit\.", r"^persist\.vendor\."
    r"(debug_policy|fulldump)", r"^persist\.sys\.(walt|tzdbg)", r"^persist\.debug\.coresight",
    # Google apps and setup
    r"^ro\.com\.google\.", r"^ro\.opa\.", r"^ro\.setupwizard\.", r"^setupwizard\.",
    r"^ro\.appsearch\.",
    # stock Bluetooth stack (ours is AOSP), sounds, launcher, emulator and legacy HWUI caches
    r"^ro\.bluetooth\.library_name$", r"^ro\.config\.ringtone", r"^ro\.launcher\.",
    r"^(qemu|ro\.kernel\.qemu)\.", r"^ro\.hwui\.", r"^persist\.sys\.force_sw_gles$",
    r"^arm64\.memtag\.", r"^ro\.boot\.", r"^ro\.config\.isolated_compilation_enabled$",
    r"^persist\.device_config\.", r"^persist\.radio\.nt\.", r"^ro\.com\.android\.prov_mobiledata$",
    r"^bluetooth\.device_id\.", r"^sys\.qca1530$",
    # system properties in stock's vendor build.prop, which init refuses from /vendor
    r"^persist\.sys\.vib_internal$",
    # stock camera app lists: device.mk names ours
    r"^(vendor\.camera\.aux\.packagelist|persist\.vendor\.camera\.privapp\.list)$",
    # system copy of a codec switch vendor.prop sets (debug.stagefright.ccodec=4)
    r"^debug\.stagefright\.ccodec$",
    # other Nothing devices' feature flags
    r"^ro\.vendor\.nothing\.feature\.diff\.(device|plus|product)\.(?!Metroid)",
)]


def props(path):
    """Ordered key -> value of a prop file, last assignment wins (as init does)."""
    res = {}
    for line in open(path, errors="replace"):
        line = line.strip()
        if line and not line.startswith(("#", "import ")) and "=" in line:
            k, v = line.split("=", 1)
            res.pop(k, None)
            res[k] = v
    return res


ours = set()
for d, _, fs in os.walk(out):
    rel = os.path.relpath(d, out)
    if rel.split(os.sep)[0] in ("obj", "symbols", "recovery", "root", "testcases"):
        continue
    for f in fs:
        if f.endswith(".prop"):
            ours |= props(os.path.join(d, f)).keys()

for src, dst in TARGETS.items():
    path = os.path.join(stock, src)
    if not os.path.exists(path):
        continue
    lines = [f"{k}={v}" for k, v in props(path).items()
             if v and k not in ours and not any(p.search(k) for p in SKIP)]
    if lines:
        print(f"### {dst} (from stock {src}, {len(lines)})")
        print("\n".join(lines))
        print()
