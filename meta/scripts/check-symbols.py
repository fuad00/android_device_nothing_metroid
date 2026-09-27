#!/usr/bin/env python3
# List undefined dynamic symbols of vendor/odm ELFs that nothing in their DT_NEEDED closure
# defines. check-needed.py only proves that the libraries exist; a stock blob built against a
# different AOSP release can still reference a function the source-built library dropped or
# renamed, and fails at dlopen ("cannot locate symbol"). Weak references are ignored.
#   check-symbols.py <out/target/product/metroid> <llvm-nm> [path prefix ...]
import collections, os, subprocess, sys

O, NM = sys.argv[1:3]
PREFIXES = tuple(sys.argv[3:]) or ("vendor/", "odm/")
SKIP = ("vendor/lib64/rfs/", "vendor/lib/rfsa/", "vendor/lib64/rfsa/")
# Where the vendor linker namespace finds libraries: vendor and odm, and LLNDK libraries from
# system or their APEX (libcom.android.tethering.connectivity_native lives in tethering)
SEARCH = ["vendor/lib64", "vendor/lib64/hw", "vendor/lib64/egl", "odm/lib64", "odm/lib64/hw"]
LLNDK_SEARCH = ["system/lib64", "apex/com.android.runtime/lib64/bionic"] + sorted(
    os.path.relpath(os.path.join(O, "apex", a, "lib64"), O)
    for a in os.listdir(os.path.join(O, "apex")) if os.path.isdir(os.path.join(O, "apex", a, "lib64")))
LLNDK = {l.strip() for l in open(os.path.join(O, "system/etc/llndk.libraries.txt")) if l.strip()}
LLNDK |= {"libc.so", "libm.so", "libdl.so"}

def is_elf(p):
    try:
        with open(p, "rb") as h:
            return h.read(4) == b"\x7fELF"
    except OSError:
        return False

def find(name):
    for d in SEARCH + (LLNDK_SEARCH if name in LLNDK else []):
        p = os.path.join(O, d, name)
        if os.path.isfile(p):
            return p
    return None

_nm = {}
def nm(path):
    if path not in _nm:
        out = subprocess.run([NM, "-D", "--format=posix", path], capture_output=True, text=True).stdout
        defined, undef = set(), set()
        for line in out.splitlines():
            parts = line.split()
            if len(parts) < 2:
                continue
            sym, kind = parts[0].split("@")[0], parts[1]
            if kind == "U":
                undef.add(sym)
            elif kind not in ("w", "v"):
                defined.add(sym)
        _nm[path] = (defined, undef)
    return _nm[path]

_needed = {}
def needed(path):
    if path not in _needed:
        out = subprocess.run([NM.replace("llvm-nm", "llvm-readelf"), "-d", path],
                             capture_output=True, text=True).stdout
        _needed[path] = [l.split("[", 1)[1].rstrip("]") for l in out.splitlines() if "(NEEDED)" in l]
    return _needed[path]

def closure(path):
    seen, todo, libs = {path}, [path], []
    while todo:
        for n in needed(todo.pop()):
            p = find(n)
            if p and p not in seen:
                seen.add(p)
                todo.append(p)
                libs.append(p)
    return libs

report = collections.defaultdict(list)
for pre in PREFIXES:
    for d, _, fs in os.walk(os.path.join(O, pre)):
        for f in fs:
            path = os.path.join(d, f)
            rel = os.path.relpath(path, O)
            if os.path.islink(path) or rel.startswith(SKIP) or f.lower().endswith("skel.so") or not is_elf(path):
                continue
            _, undef = nm(path)
            if not undef:
                continue
            have = set(nm(path)[0])
            for lib in closure(path):
                have |= nm(lib)[0]
            for s in sorted(undef - have):
                report[rel].append(s)

for rel, syms in sorted(report.items()):
    print(f"{rel}: {len(syms)}")
    for s in syms[:8]:
        print(f"    {s}")
print(len(report), "ELFs with unresolved symbols")
