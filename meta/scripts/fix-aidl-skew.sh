#!/usr/bin/env bash
# Loop: soong analysis -> blobs with "multiple versions of the same aidl_interface" -> DISABLE_DEPS
# on them + install the interface versions they load. Stops when no such error is left.
T=/root/nothing_phone_3/lineage; DEV=$T/device/nothing/metroid; DUMP=/root/nothing_phone_3/stock/Metroid_B4.1-260814-1733
RE=$(ls $T/prebuilts/clang/host/linux-x86/clang-r*/bin/llvm-readelf | tail -1)
PK=$DEV/meta/docs/disable-deps-interfaces.txt; touch $PK
for round in $(seq 1 40); do
  (cd $DEV && ./setup-makefiles.py > /root/nothing_phone_3/logs/setup_last.log 2>&1) || { echo "setup failed"; exit 1; }
  L=/root/nothing_phone_3/logs/skew_round.log
  (cd $T && source build/envsetup.sh >/dev/null 2>&1 && breakfast metroid userdebug >/dev/null 2>&1 && m nothing) > $L 2>&1
  mods=$(grep -oE 'module "[^"]+" variant "[^"]+": depends on multiple versions' $L | sed -E 's/module "(prebuilt_)?([^"]+)".*/\2/' | sort -u)
  if [ -z "$mods" ]; then echo "round $round: no version-skew errors left"; grep -E "^FAILED|error:" $L | head -3; exit 0; fi
  changed=0
  for m in $mods; do
    line=$(grep -nE "^-?[^#]*/$m(\.so)?(;[^:]*)?$|^-?[^#]*:[^;]*/$m(\.so)?(;.*)?$" $DEV/proprietary-files.txt | grep -v DISABLE_DEPS | head -1)
    [ -n "$line" ] || { echo "round $round: $m not a blob, cannot fix"; continue; }
    n=${line%%:*}; src=$(echo "${line#*:}" | sed -E 's/^-//; s/[;:].*//')
    sed -i "${n}s/\$/;DISABLE_DEPS/" $DEV/proprietary-files.txt
    $RE -d "$DUMP/$src" | grep NEEDED | grep -oE '\[[^]]+-V[0-9]+-(ndk|cpp)\.so\]' | tr -d '[]' | sed 's/\.so$//' >> $PK
    echo "round $round: DISABLE_DEPS $src"; changed=1
  done
  sort -u -o $PK $PK
  [ $changed = 1 ] || { echo "round $round: nothing fixable"; exit 1; }
done
