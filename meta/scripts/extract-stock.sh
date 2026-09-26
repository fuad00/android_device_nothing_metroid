#!/bin/bash
# Server: dump a metroid stock full OTA (all partitions, images kept) with LineageOS extract-utils.
# Usage: extract-stock.sh <build>
set -euo pipefail
B=${1:?build}
S=/root/nothing_phone_3/stock
cd /root/oneplus_10_pro_lineage/lineage
python3 tools/extract-utils/extract.py --all --keep-images "$S/Metroid_$B.zip"
