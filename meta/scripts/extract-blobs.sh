#!/usr/bin/env bash
# Server: regenerate vendor/nothing/metroid from the unpacked stock dump (scripts/extract-stock.sh
# + extract-stock-images.sh). Firmware images are linked into the dump root, where extract-utils
# looks for the partitions listed in proprietary-firmware.txt.
#   extract-blobs.sh [build]   (default B4.1-260814-1733)
set -eo pipefail
B=${1:-B4.1-260814-1733}
DUMP=/root/nothing_phone_3/stock/Metroid_$B
TOP=/root/oneplus_10_pro_lineage/lineage
for f in "$DUMP"/images/*.img; do
  n=$(basename "$f"); [ -e "$DUMP/$n" ] || ln -s "images/$n" "$DUMP/$n"
done
cd "$TOP/device/nothing/metroid"
./extract-files.py "$DUMP"
