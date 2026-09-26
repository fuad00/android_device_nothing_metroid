#!/bin/bash
# Install a stock full A/B OTA into the INACTIVE slot with update_engine (root via adb su).
# The active slot is left untouched; if the new slot fails to boot, the bootloader
# falls back to it. update_engine verifies the payload signature with Nothing's key.
# Usage: stock-ota-update.sh <serial> <full-ota.zip>
set -euo pipefail
S=${1:?serial}; ZIP=${2:?ota zip}
HERE=$(cd "$(dirname "$0")" && pwd)
INFO=$("$HERE/ota_payload_info.py" "$ZIP")
OFF=$(sed -n 's/^payload.bin offset=\([0-9]*\) .*/\1/p' <<<"$INFO")
SIZE=$(sed -n 's/^payload.bin offset=[0-9]* size=\([0-9]*\) .*/\1/p' <<<"$INFO")
echo "payload offset=$OFF size=$SIZE"
RUN=$(mktemp)
{
  echo 'H="$(cat <<END'
  grep -E '^(FILE_HASH|FILE_SIZE|METADATA_HASH|METADATA_SIZE)=' <<<"$INFO"
  echo 'END'
  echo ')"'
  echo "update_engine_client --update --follow --payload=file:///data/ota_package/update.zip --offset=$OFF --size=$SIZE --headers=\"\$H\""
} > "$RUN"
adb -s "$S" push -q "$RUN" /data/local/tmp/ota_run.sh; rm "$RUN"
adb -s "$S" push "$ZIP" /data/local/tmp/update.zip
adb -s "$S" shell "su -c 'mkdir -p /data/ota_package && mv /data/local/tmp/update.zip /data/ota_package/update.zip && chown system:cache /data/ota_package/update.zip && chmod 0644 /data/ota_package/update.zip && restorecon /data/ota_package/update.zip'"
adb -s "$S" shell "su -c 'sh /data/local/tmp/ota_run.sh'"
