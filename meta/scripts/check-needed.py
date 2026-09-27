#!/usr/bin/env python3
# List NEEDED libraries of every ELF in the product out dir that no partition provides.
#   check-needed.py <out/target/product/metroid> <llvm-readelf>
import collections, os, re, subprocess, sys

O, RE = sys.argv[1:]
parts = ["system", "system_ext", "product", "vendor", "odm", "apex"]
have = {"libc.so", "libm.so", "libdl.so", "libdl_android.so", "ld-android.so"}
elfs = []
for p in parts:
    for d, _, fs in os.walk(os.path.join(O, p)):
        for f in fs:
            path = os.path.join(d, f)
            if f.endswith(".so"):
                have.add(f)
            if os.path.islink(path):
                continue
            try:
                with open(path, "rb") as h:
                    if h.read(4) != b"\x7fELF":
                        continue
            except OSError:
                continue
            elfs.append(path)

miss = collections.defaultdict(list)
for e in elfs:
    out = subprocess.run([RE, "-d", e], capture_output=True, text=True).stdout
    for n in re.findall(r"NEEDED.*\[([^\]]+)\]", out):
        if n not in have:
            miss[n].append(os.path.relpath(e, O))
for n, users in sorted(miss.items()):
    print(f"{n}: {len(users)}: {' '.join(users[:5])}")
print(len(elfs), "elfs,", len(miss), "missing libs")
