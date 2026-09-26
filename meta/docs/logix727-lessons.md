# Уроки из logix727/android_device_nothing_metroid (lineage-23.0)

Выжимка 26.09.2026 (коммит 7fc74f7). Пути — в том репозитории. [REAL] — требование устройства, [HACK] — не повторять, [CHECK] — перепроверить.

All paths below are relative to `~/Downloads/nothing_phone_3/ref/android_device_nothing_metroid/`. Each item is **problem → cause → fix**, tagged:

- **[REAL]** is a genuine device requirement.
- **[HACK]** is a workaround to avoid.
- **[CHECK]** means the diagnosis looks shaky and should be re-verified.

Two things about their setup affect how the lessons carry over:
- **Kernel:** they ship Google's prebuilt GKI Image (6.6.102, build `ab14350911`) with vendor modules built from source.
- **Kernel source branch:** they use `kernel_nothingoss_b16`. The branch named `kernel_nothingoss` is 6.6.57, and its modules are rejected at first stage (`BoardConfig.mk:147-148`).

## Boot, cmdline, bootconfig
1. **Hang on the Nothing logo once vendor_boot is built from source** → with boot header v4 the cmdline goes into vendor_boot, and it was missing stock tokens → add `video=vfb:640x400,bpp=32,memsize=3072000 qcom_geni_serial.con_enabled=0 console=ttynull`. Their full working string also has `bootopt=64S3,32N2,64N2 erofs.reserved_pages=64 nosoftlockup log_buf_len=1M ignore_loglevel printk.devkmsg=on` (`BoardConfig.mk:111-120`). [REAL]
2. **Bootconfig** (`BoardConfig.mk:125-138`):
   - `androidboot.hardware=qcom`, `memcg=1`, `usbcontroller=a600000.dwc3`, `hypervisor.protected_vm.supported=true`, `vendor.qspa=true`, `serialconsole=0`.
   - `load_modules_parallel=false`: stock bootconfig says true, but the known-good vendor_boot overrides it. This is a conservative choice, not a proven need.
3. **Three recovery bootloops, even with OrangeFox** → `androidboot.init_fatal_reboot_target=recovery` → never add it (`BoardConfig.mk:100-106`). [REAL]
4. **Removing `selinux=permissive` did nothing** → it was set in both the cmdline and bootconfig (`BoardConfig.mk:108-109`).
5. **init_boot came out at 18 MB for an 8 MB partition** → without `PRODUCT_BUILD_VENDOR_BOOT_IMAGE := true`, all 341 vendor ramdisk modules fold into the generic ramdisk (`device.mk:112-118`). [REAL]
6. **Invariants:** vendor_boot page size stays `0x1000`, and vendor stays ext4 (`AGENTS.md:37`).

## Kernel and modules
7. **Hard reset about 7-9 s into boot, no panic** → vendor_dlkm/system_dlkm were empty, so secure-side modules (tz_log_dlkm, spss_utils, qce50_dlkm, cdsprm) never loaded → populate both with the stock load order (`dlkm_modules.mk:5-12`, `kernel/vendor_dlkm-meta/modules.load`). [REAL]
8. **vendor_boot ramdisk contents** → use `modules.load.vendor_boot` (131 entries) plus `modules.load.recovery` (343). The module set is the dependency closure plus `cfg80211`, `mac80211` and `tz_log_dlkm` (`kernel/stage_kernel_artifacts.sh:271-305`).
9. **Blocklist missing** → the build does not generate `modules.blocklist` (62 entries), but first-stage init reads it → copy it into the vendor ramdisk (`device.mk:125-129`). [REAL]
10. **Broken first stage in recovery mode** → the recovery ramdisk's `modules.dep` overwrites vendor_boot's when the ramdisks merge → ship no `BOARD_RECOVERY_KERNEL_MODULES` (`BoardConfig.mk:264-273`). [REAL]
11. **No wlan0 and no BT** → `modules.dep` used bare filenames → paths must be absolute, with system_dlkm modules under `/system/lib/modules`. Chain: rfkill → cfg80211 → qca_cld3_wcn7750 (`stage_kernel_artifacts.sh:229-238`).
12. **Modules refused by the kernel** → stripping with `--strip-all` removes vermagic/CRCs → use `--strip-debug` (`:188`).
13. **Boot animation spins forever under enforcing** → module loading stalls → `allow vendor_modprobe self:capability sys_nice` (`sepolicy/vendor/enforcing.te:96-98`). [REAL]
14. **Mobile data fails with `0x1004` ("DSI init not yet completed")** → Qualcomm's data stack needs AF_TIPC, and a `tipc.ko` from a different GKI build was rejected (protected symbol `tipc_dump_done`) → build tipc from the same kernel tree and load it via system_dlkm `modules.load` (`BUGS.md:246-255`). This applies to you directly.
15. **If you build GKI from source:** android15-6.6 HEAD `gki_defconfig` lacks `CONFIG_TLS`, but the device loads `tls.ko` (`kernel/gki/README.md:62-67`).
16. **Kleaf build issues:**
    - camera-kernel needs `--//vendor/qcom/opensource/camera-kernel:project_name=sun` (`stage_kernel_artifacts.sh:32-34`).
    - A mixed build gives "exported twice" in modpost, fixed by `kernel/patches/build-kernel-module-symvers.patch`.
    - Kernel patch 0001 imports missing NothingOSS module sources. Patches 0003/0004 fix real IRQ-flag and use-after-free bugs in Nothing's named-affinity driver.
17. **DTB/DTBO** → Kleaf never compiles `vendor/qcom/opensource/*-devicetree`, leaving 86 compatibles missing (`kernel/build_tuna_dtb.sh:6-19`). [REAL]
    - Merge the SoC overlays into `tuna.dtb` with fdtoverlaymerge.
    - `dtb.img` = merged tuna + tuna7 + tunap concatenated (`stage_kernel_artifacts.sh:335`).
    - dtbo holds one fully merged overlay per variant.
    - You must include `arbok-camera-sensor-t0`, or the camera HAL finds 0 cameras.
    - You must include the nested `wlan/wlan-devicetree`, or there is no wlan0 (`build_tuna_dtb.sh:49-56, 92-106`).
18. **Hard reset about 190 s after entering s2idle** → `qcom_wdt_core` doesn't stop the Gunyah watchdog on s2idle → port upstream `de06bc12a008` and `c4d33e4f024`. That fix is necessary but still unresolved (`BUGS.md:1492-1547`). Check your kernel source for it.
19. **RNDIS broken** → `dwc3-msm` never issues SETTRANSFRESOURCE for GSI endpoints → port NothingOSS `DWC3_EP_RESOURCE_ALLOCATED` (`BUGS.md:1029-1038`).
20. **ST NFC modules have no published source** → `stm_nfc_i2c` and `stm_st54se_gpio` must be extracted from stock (`kernel/prebuilt-modules/README.md`).

## Partitions, fstab, FBE, AVB
21. **Logo hang with no init FATAL** → the bootloader sets `fstab_suffix=default`, so `fstab.qcom` is ignored → put `fstab.default` in the vendor_boot `first_stage_ramdisk` (`device.mk:131-142`). [REAL]
22. **FBE silently off (`ro.crypto.state=unsupported`)** → vold reads `/vendor/etc/fstab.default`, and a stock blob copy was shadowing theirs (hidden by `BUILD_BROKEN_DUP_RULES`) → put the FBE options in both places (`device.mk:257-264`). The flags are at `rootdir/etc/fstab.default:59`: wrappedkey_v0 plus metadata encryption.
23. **1 sensor instead of 39, no wlan0, ADSP never starts** → `/vendor/{firmware_mnt,dsp,bt_firmware}` mount points don't exist → create them as `prebuilt_root` in vendor.img. Also add the `wlan_mac.bin` and `wlanmdsp.otaupdate` symlinks (`device.mk:144-172`). [REAL]
24. **Reboot to bootloader about 15 s in (looks like a vendor crash loop)** → dm-verity fails on first-stage mounts → set `BOARD_AVB_VBMETA_VENDOR := vendor vendor_dlkm system_dlkm odm` (`BoardConfig.mk:305-316`). [REAL]
25. **update_engine can't open `vbmeta_vendor_[ab]`** → label it `vendor_custom_ab_block_device` (`sepolicy/vendor/file_contexts:9`).
26. **Launch API level** → 35, with board API 202404 (`BUGS.md:616-627`).
27. **vbmeta `--set_hashtree_disabled_flag`**, only there so GApps add-ons can modify partitions (`BoardConfig.mk:283-286`). [HACK]
28. **Recovery never booted** → keep `recovery.fstab` in stock shape. No dlkm/persist/modem entries, and never strip FBE flags (`recovery.fstab:1-12`).

## SELinux
29. **keystore2 crash loop and fatal reboot at about 21 s** → QTI HAL binaries unlabeled → include `device/qcom/sepolicy_vndr` (`BoardConfig.mk:355-363`).
30. **Main enforcing boot blocker** → the TEE daemon (qseecomd) must read the gpt/xbl/boot block devices, or keymint, gatekeeper and system_server all die (`enforcing.te:10-19`). [REAL]
31. **Nothing's binary names miss AOSP labels** → unlabeled `power.stats-service` meant no IPowerStats and a system_server loop; the camera shim ran as init (`file_contexts:65-84`).
32. **Denials don't show in dmesg** → collect AVCs from logcat (`enforcing.te:5-7`).
33. **Fingerprint never captures** → allow `hal_fingerprint_default` access to `/proc/touchpanel/fod_mode` (`enforcing.te:43-46`).
34. **Android 16 seapp_contexts** → one name-only rule invalidates the whole table, so zygote cannot start system_server (`BUGS.md:69-74`).
35. **Service naming** → Nothing/Goodix AIDL services need their own service types (`sepolicy/vendor/service.te:1-4`), and `nothing.radio.ntphone` maps to `radio_service`.

## HALs and blobs
- **Audio:** `audiohalservice.qti` must be in `PRODUCT_PACKAGES`. Without it audioserver dies and system_server loops; their earlier "NDK ABI skew" explanation was wrong (`device.mk:344-352`, `BoardConfig.mk:195-210`). A duplicate `audio.core` VINTF fragment only fails at the `bacon` checkvintf step (`BoardConfig.mk:344-349`).
- **Media/ABI:** the device is 64-bit only, so 32-bit mediaserver/drmserver hit "Exec format error" and the camera preview goes black. Use `TARGET_DYNAMIC_64_32_*` (`BoardConfig.mk:365-369`). [REAL] Their tree still declares a 32-bit second arch; drop it.
- **Camera:**
  - Morpho EIS crashes with SIGILL, worked around with `persist.vendor.morpho.eis.force_gmenode=1` and EIS off (`device.mk:370-375`). [HACK]
  - `vendor.gralloc.enable_logs` must be 0, or QtiMapper5 logging reads freed memory (`vendor.prop:156`).
  - Declare the offline and postproc AIDL services (`BUGS.md:1605-1619`).
  - Topology: logical camera 4 for SAT zoom, physical camera 0 for UHD/60 fps.
- **Face:** Nothing's face HAL owns the camera, so Settings must pass its preview Surface (`patches/settings/0002`). The stock face RC needs an `interface` line (`extract-files.py:45-52`).
- **UDFPS:**
  - The HAL reports 1080x2400-space coordinates, but the panel only runs 1260x2800. Override to 630,2539,r107 via `config_udfps_sensor_props` plus a framework patch (`overlay/frameworks/base/core/res/res/values/config.xml:74-101`). [REAL]
  - Never use `config_sfps_sensor_props`; SystemUI crash-loops.
  - LHBM needs 120 Hz held before touch (`frameworks_base/0004`).
  - `vendor.prop:73` holds a stale location value.
- **Vibrator:** use the stock RC. It sets permissions on `/dev/aw86927_haptic` and `vibrator_nt`, plus the RichTap env vars (`patches/vibrator`). The stock HAL still advertises no effects (unresolved).
- **Wi-Fi:** use the stock wifi HAL service. The TEE daemon (via libdrmfs) needs `libxml2.vendor` (`device.mk:217-225`).
- **Stock RC `disabled` lines:** sensors and BT had it, so they were declared but never started, which blocks system_server's watchdog and leaves BT stuck turning on (`proprietary_force_copy.mk:218-224`). cnd, qms, perf2 and c2 RCs need it stripped too (`extract-files.py`). Never drop a blob whose module owns a VINTF fragment (ipacm owns tetheroffload, `:229-231`).
- **Thermal:** the generic HAL maps skin temperature to a nonexistent `sys-therm-3`. Use the stock thermal HAL plus `sltntc` (`BUGS.md:583-592`).
- **Charging and power:** add the Nothing charge HAL VINTF entry, `binder_use()`, and touchpanel proc access (`BUGS.md:675-708`). Add the Power AIDL fragment (`:557-569`).
- **Telephony:**
  - `nt-telephony-interface` must be in both `PRODUCT_BOOT_JARS` and `PRODUCT_PACKAGES` (`device.mk:46-51`).
  - Ship QtiTelephony, QtiTelephonyService, qcrilmsgtunnel and datastatusnotification, with explicit privapp permission grants.
  - Set device IMS capabilities to true and point the IWLAN packages at `vendor.qti.iwlan`.
  - Set `ro.telephony.default_network=26,26` (`system.prop:18`).
  - The modem firmware generation must match userspace on both slots.
  - SIM slot 1 is a pSIM/eSIM hardware switch (`BUGS.md:506-543`).
- **USB:** change `ncm.0` to `ncm.gs6`, and add the Tethering and Connectivity RROs.
- **Bluetooth:** the stock audio provider is AIDL v4, so suppress the v5 fragment (`device.mk:3-5`). A2DP offload is disabled as a workaround (`vendor.prop:44`). [HACK]
- **Essential Key:** scancode 250, handled by the key handler (`keylayout/gpio-keys.kl`).
- **Glyph:** not ported; the packages are commented out (`device.mk:323-328`).

## Properties
- `/vendor/build.prop` "loads too late for zygote", so dalvik heap and morpho props were moved to system (`device.mk:27-38, 370-375`). [CHECK]
- `ro.hw_timeout_multiplier=4` only covers the slow first boot caused by `WITH_DEXPREOPT := false` (`device.mk:334-340`). [HACK]
- `persist.sys.usb.config=adb` (`vendor.prop:240`). [HACK]
- `PRODUCT_PRECOMPILED_SEPOLICY := false` (`device.mk:313-314`). [CHECK]
- `boot_level_key.strategy=...MAX_USES_PER_BOOT`, because the TEE keymint rejects EARLY_BOOT_ONLY. Likely [REAL], but verify.

## Recovery
- **Power/volume keys dead** → the squeeze-sensor input nodes exceed minui's 16-device cap → raise to 32 (`patches/bootable_recovery/0001`). [REAL]
- **Recovery touch** → put the FocalTech firmware in the vendor ramdisk (`device.mk:178-181`).
- **Recovery adb shows unauthorized** → expected; don't ship adb keys (`:183-189`).
- **GApps lost after sideload** → A/B recovery sideload does not run addon.d, so GApps must be sideloaded again.

## What each patch in `patches/` does
**Keep (real fixes or real device needs)**
- `recovery/0001`: minui input-device cap raised to 32.
- `frameworks_base/0001` (UDFPS part): coordinate override for AIDL sensors.
- `frameworks_base/0004`: hold max refresh while the UDFPS overlay is up.
- `settings/0002`: face HAL owns the camera preview.
- `vibrator`: stock RC and build selection.
- `hardware_interfaces/0003`: select the stock BT audio VINTF declaration.
- `frameworks_av/0002`: upstream AOSP media_quality lookup fix; `system_sepolicy/0001` is its follow-up.
- `audio_agm`: fixes a 64-bit subtraction bug.
- `vendor_apn`: carrier APN data.

**Upstreamable robustness fixes**
- `frameworks_base/0005`: recover after USB gadget HAL death.
- `connectivity/0001-0002`: NCM tethering race.
- `build_soong`: boot image security-patch property.

**Hacks (avoid)**
- `frameworks_base/0001`: removes a `LOG_ALWAYS_FATAL` in ExternalCaptureStateTracker, and changes `isDeclared` to `checkService` in UsbGadgetAidl.
- `frameworks_base/0002`: suppresses the fingerprint unlock ripple.
- `build_make`: tolerate duplicate target-files entries.
- `audio_primary_hal`: marks the effect and sound-trigger HALs non-mandatory.
- `telephony_provider`: APN refresh, only needed because their build ID never changes.
- `audiofx` and `frameworks_base/0003`: AudioFX keepalive.
- `adb` and `recovery/0002`: sideload progress and result reporting.
- `aperture/0001-0004`: device camera routing inside the app.

**Build shims, probably unnecessary with an inline kernel build**
- `vendor_lineage`: prebuilt kernel headers. Instead, export the techpack display/camera/eva/synx/vidc headers from your kernel build.
- `dataipa`, `display_hal`, `audio_pal`: missing kernel header copies.
- `data_ipa_cfg_mgr`, `hardware_interfaces/0001-0002`, `packages_modules_bluetooth`, `frameworks_av/0001`, `packages_modules_common`: missing include paths and dependencies.
