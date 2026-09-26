#!/bin/bash
# Server: extract the non-default partitions (dlkm, boot chain, vbmeta, firmware) of a
# metroid full OTA dump into <dump>/images/, then unpack the dlkm EROFS images next to the others.
# Usage: extract-stock-images.sh <build>   (after extract-stock.sh)
set -euo pipefail
B=${1:?build}
D=/root/nothing_phone_3/stock/Metroid_$B
X=/root/oneplus_10_pro_lineage/lineage/prebuilts/extract-tools/linux-x86/bin/ota_extractor
P=vendor_dlkm,system_dlkm,odm_dlkm,boot,init_boot,vendor_boot,dtbo,recovery,vbmeta,vbmeta_system,vbmeta_vendor,abl,aop,aop_config,bluetooth,cpucp,cpucp_dtb,devcfg,dsp,featenabler,hyp,imagefv,keymaster,modem,multiimgoem,multiimgqti,pvmfw,qupfw,shrm,soccp_dcd,soccp_debug,tz,uefi,uefisecapp,xbl,xbl_config,xbl_ramdump
mkdir -p "$D/images"
"$X" --payload "$D/payload.bin" --output-dir "$D/images" --partitions "$P"
for p in vendor_dlkm system_dlkm odm_dlkm; do
  [ -f "$D/images/$p.img" ] || continue
  rm -rf "$D/$p"; mkdir "$D/$p"
  fsck.erofs --extract="$D/$p" "$D/images/$p.img"
done
(cd "$D/images" && sha256sum *.img > SHA256SUMS)
ls -la "$D/images"
