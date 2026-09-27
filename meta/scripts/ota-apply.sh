#!/usr/bin/env bash
# Mac: install an OTA zip (incremental or full) on the running phone through update_engine, the
# way the Updater app does. On Virtual A/B, recovery sideload refuses incrementals; this does not.
# Needs adb root and a debug build (update_engine_client ships in PRODUCT_PACKAGES_DEBUG).
#   ota-apply.sh <ota.zip> [serial]     then reboot when it reports UPDATED_NEED_REBOOT
# An incremental checks every source block: vbmeta flags left by adb disable-verity or remount
# make it fail with kDownloadStateInitializationError. Restore the release's vbmeta first.
set -euo pipefail
ZIP=${1:?ota zip}
SERIAL=${2:-<serial>}
adb() { command adb -s "$SERIAL" "$@"; }

read -r OFFSET SIZE < <(python3 - "$ZIP" <<'PY'
import struct, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
i = z.getinfo("payload.bin")
assert i.compress_type == zipfile.ZIP_STORED, "payload.bin must be stored"
with open(sys.argv[1], "rb") as f:
    f.seek(i.header_offset)
    n, e = struct.unpack("<HH", f.read(30)[26:30])
print(i.header_offset + 30 + n + e, i.file_size)
PY
)
HEADERS=$(unzip -p "$ZIP" payload_properties.txt)

adb root >/dev/null
adb wait-for-device
adb shell mkdir -p /data/ota_package
adb push "$ZIP" /data/ota_package/update.zip >/dev/null
adb shell 'chown system:cache /data/ota_package/update.zip && chmod 644 /data/ota_package/update.zip && restorecon /data/ota_package/update.zip'
adb shell "update_engine_client --update --follow --payload=file:///data/ota_package/update.zip \
    --offset=$OFFSET --size=$SIZE --headers='$HEADERS'" | grep -vE "DOWNLOADING|VERIFYING|FINALIZING"
