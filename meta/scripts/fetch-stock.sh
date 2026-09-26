#!/bin/bash
# Server: download a Nothing OS full OTA for metroid from the nothing_archive mirror
# on archive.org and check it against the md5/sha1 published in the item metadata.
# Usage: fetch-stock.sh <build, e.g. B4.1-260814-1733>
set -euo pipefail
B=${1:?build}
D=/root/nothing_phone_3/stock; mkdir -p "$D"; cd "$D"
F=Metroid_$B.zip
P=spike0en/fullota/metroid/$F
curl -L -C - --retry 10 --retry-delay 5 -o "$F" "https://archive.org/download/nothing-archive/$P"
read -r MD5 SHA1 < <(curl -s https://archive.org/metadata/nothing-archive | python3 -c "
import json,sys
for f in json.load(sys.stdin)['files']:
    if f['name']=='$P': print(f['md5'], f['sha1'])")
echo "$MD5  $F" | md5sum -c
echo "$SHA1  $F" | sha1sum -c
