#!/bin/bash
# Back up every partition except userdata/super/rawdump (plus the GPT of each LUN)
# from a rooted phone to the Mac. Needs `su` over adb (Magisk).
# Usage: backup-partitions.sh <serial> <out-dir>
set -euo pipefail
S=${1:?serial}; OUT=${2:?out dir}
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=/data/local/tmp/dump
adb -s "$S" push -q "$HERE/device/dump_partitions.sh" /data/local/tmp/
adb -s "$S" shell "su -c 'sh /data/local/tmp/dump_partitions.sh $TMP && chmod -R a+rX $TMP'"
mkdir -p "$OUT"
adb -s "$S" pull "$TMP/." "$OUT/"
(cd "$OUT" && shasum -a 256 -c SHA256SUMS | grep -v ': OK$' || echo "all checksums OK")
adb -s "$S" shell "su -c 'rm -rf $TMP /data/local/tmp/dump_partitions.sh'"
