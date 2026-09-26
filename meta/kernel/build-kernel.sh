#!/usr/bin/env bash
# Build the metroid kernel with Kleaf: GKI Image (//common), msm-kernel modules and the Qualcomm/
# Nothing techpack modules for sun_perf, plus the dtc tools build_tuna_dtb.sh needs. Output lands in
# <ws>/bazel-bin/...; stage-kernel.sh collects it into one directory.
#   build-kernel.sh [kernel-workspace]   (default /root/nothing_phone_3/kernelws)
# Log: /root/nothing_phone_3/logs/kernel_build_<date>.log (current_kernel_build.log links to it)
set -o pipefail
WS=${1:-/root/nothing_phone_3/kernelws}
LOGS=/root/nothing_phone_3/logs
LOG=$LOGS/kernel_build_$(date +%Y%m%d_%H%M).log
ln -sfn "$LOG" "$LOGS/current_kernel_build.log"
cd "$WS" || exit 1
{
  echo "KERNEL BUILD START $(date)"
  for p in msm-kernel common build/kernel; do echo "$p $(git -C $p log -1 --format='%h %s')"; done
  # camera-kernel picks its project from this flag (without it camera.ko fails to build)
  ./build/kernel/kleaf/bazel.sh build --noenable_bzlmod --keep_going \
      --//vendor/qcom/opensource/camera-kernel:project_name=sun \
      --target_pattern_file=vendor-module-targets.txt
  rc=$?
  echo "KERNEL BUILD END $(date) rc=$rc"
  exit $rc
} > "$LOG" 2>&1
rc=$?
echo "$LOG rc=$rc"
exit $rc
