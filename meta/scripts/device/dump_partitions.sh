#!/system/bin/sh
# Runs as root on the phone. Dumps every partition except userdata/super/rawdump,
# plus primary/backup GPT of each UFS LUN, into $OUT with a sha256 list.
OUT=${1:-/data/local/tmp/dump}
rm -rf "$OUT"; mkdir -p "$OUT/gpt"
cd /dev/block/by-name || exit 1
for p in *; do
  case "$p" in userdata|super|rawdump|sd[a-z]) continue;; esac
  dd if="$p" of="$OUT/$p.img" bs=1M 2>/dev/null || echo "FAIL $p"
done
for l in sda sdb sdc sdd sde sdf; do
  n=$(cat /sys/class/block/$l/size)            # 512-byte units
  blocks=$((n / 8))                             # 4K logical blocks
  dd if=/dev/block/$l of="$OUT/gpt/$l.primary.bin" bs=4096 count=6 2>/dev/null
  dd if=/dev/block/$l of="$OUT/gpt/$l.backup.bin" bs=4096 skip=$((blocks - 5)) count=5 2>/dev/null
  echo "$l $n" >> "$OUT/gpt/lun_sizes.txt"
done
cat /proc/cmdline > "$OUT/proc_cmdline.txt"
cat /proc/bootconfig > "$OUT/proc_bootconfig.txt" 2>/dev/null
getprop > "$OUT/getprop_root.txt"
ls -l /dev/block/by-name > "$OUT/by-name.txt"
cd "$OUT" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS
du -sh "$OUT"
echo DONE
