#!/usr/bin/env python3
# List NEEDED libraries of every ELF in the product out dir that the linker namespace of its
# partition cannot resolve. Blobs listed with DISABLE_DEPS or force-copied never tell soong
# what they link, so a library they need can silently stay out of the image.
#   vendor, odm            vendor and odm libraries + LLNDK (the vendor has no VNDK)
#   system, system_ext,    system-side libraries + APEX libraries
#   product, apex
#   check-needed.py <out/target/product/metroid> <llvm-readelf>
import collections, os, re, subprocess, sys

O, RE = sys.argv[1:]
VENDOR = ("vendor", "odm")
SYSTEM = ("system", "system_ext", "product", "apex")
# Not loaded by the Android linker: DSP-side objects (rfs/dsp, rfsa) are loaded by the DSP's
# own loader, and compos binaries run in the microdroid VM, which provides libvm_payload
SKIP = ("vendor/lib64/rfs/", "vendor/lib/rfsa/", "vendor/lib64/rfsa/", "apex/com.android.compos/")
BIONIC = {"libc.so", "libm.so", "libdl.so", "libdl_android.so", "ld-android.so"}

libs = {side: set(BIONIC) for side in ("vendor", "system")}
elfs = []
for side, parts in (("vendor", VENDOR), ("system", SYSTEM)):
    for p in parts:
        for d, _, fs in os.walk(os.path.join(O, p)):
            for f in fs:
                path = os.path.join(d, f)
                if f.endswith(".so"):
                    libs[side].add(f)
                if os.path.islink(path):
                    continue
                rel = os.path.relpath(path, O)
                # QNN HTP skeletons (lib*Skel.so) are DSP objects wherever they are installed
                if rel.startswith(SKIP) or f.lower().endswith("skel.so"):
                    continue
                try:
                    with open(path, "rb") as h:
                        if h.read(4) != b"\x7fELF":
                            continue
                except OSError:
                    continue
                elfs.append((side, path))

llndk = os.path.join(O, "system/etc/llndk.libraries.txt")
libs["vendor"] |= {l.strip() for l in open(llndk) if l.strip()}

miss = collections.defaultdict(list)
for side, e in elfs:
    out = subprocess.run([RE, "-d", e], capture_output=True, text=True).stdout
    for n in re.findall(r"NEEDED.*\[([^\]]+)\]", out):
        if n not in libs[side]:
            miss[n].append(os.path.relpath(e, O))
for n, users in sorted(miss.items()):
    print(f"{n}: {len(users)}: {' '.join(users[:5])}")
print(len(elfs), "elfs,", len(miss), "missing libs")
