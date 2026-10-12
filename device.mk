LOCAL_PATH := device/nothing/metroid

# The shipped Nothing Bluetooth audio provider is stable AIDL v4. Suppress the
# source provider's v5 fragment and install the matching stock declaration.
$(call soong_config_set_bool, metroid, stock_bluetooth_audio, true)
$(call soong_config_set_bool, metroid, stock_vibrator, true)

# Qualcomm vendor linker namespace and the stock modem RFS topology. Widevine
# needs liboemcrypto exported, while MPSS expects these paths for TFTP-backed data.
PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS += \
    hardware/qcom-caf/common/linker.config.json

PRODUCT_PACKAGES += \
    rfs_msm_mpss_hlos_symlink \
    rfs_msm_mpss_ramdumps_symlink \
    rfs_msm_mpss_readonly_firmware_symlink \
    rfs_msm_mpss_readonly_vendor_firmware_symlink \
    rfs_msm_mpss_readwrite_symlink \
    rfs_msm_mpss_shared_symlink

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# Generic ramdisk - build init_boot from source (userdebug/permissive), per onyx
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)

# Dalvik heap must land in /system/build.prop: on this device /vendor/build.prop is not loaded
# before zygote, so vendor-hosted dalvik.vm.heapsize never reaches app_process and zygote runs on
# the AndroidRuntime -Xmx16m default -> OutOfMemoryError at class preload. PRODUCT_SYSTEM_PROPERTIES
# targets the system partition only; PRODUCT_PROPERTY_OVERRIDES also feeds vendor/build.prop and the
# prop gets claimed by vendor (stripped from system).
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.heapstartsize=16m \
    dalvik.vm.heapgrowthlimit=256m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.5 \
    dalvik.vm.heapminfree=8m \
    dalvik.vm.heapmaxfree=32m

# Boot control
PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

# Stock QTI telephony resolves Nothing's Binder interface from the boot classpath.
PRODUCT_BOOT_JARS += \
    nt-telephony-interface

PRODUCT_PACKAGES += \
    nt-telephony-interface

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=ext4 \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script



# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# AIDL fastboot HAL (recovery-only), matching stock recovery layout
PRODUCT_PACKAGES += \
    android.hardware.fastboot-service.example_recovery

PRODUCT_COPY_FILES += \
    hardware/interfaces/fastboot/aidl/default/android.hardware.fastboot-service.example_recovery.rc:recovery/root/system/etc/init/android.hardware.fastboot-service.example_recovery.rc

# Health (AIDL — HIDL @2.1 is deprecated at FCM 202404 and fails VINTF)
PRODUCT_PACKAGES += \
    android.hardware.health-service.qti \
    android.hardware.health-service.qti_recovery

# Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Stock metroid exposes two modem LPA instances. Google SIM Manager supplies the
# privileged EuiccService while EuiccPolicy provides Lineage partner policy.
PRODUCT_PACKAGES += \
    EuiccPolicy \
    MetroidEuiccPartner \
    qti-telephony-hidl-wrapper-prd \
    qti_telephony_hidl_wrapper_prd.xml \
    uimlpalibrary \
    uimlpalibrary.xml \
    default-permissions-com.google.android.euicc.xml \
    privapp-permissions-com.google.android.euicc.xml \
    privapp-permissions-qti-data-status.xml \
    privapp-permissions-qti-qcc.xml \
    privapp-permissions-qti-telephony-service.xml

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.euicc.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/android.hardware.telephony.euicc.xml

PRODUCT_PRODUCT_PROPERTIES += \
    masterclear.allow_retain_esim_profiles_after_fdr=true

# vendor_boot IS built (2026-07-28). This was `false` while the tree shipped a prebuilt
# vendor_boot.img; leaving it false now is actively harmful, not merely redundant. With
# BUILDING_VENDOR_BOOT_IMAGE unset, build/make/core/Makefile folds
# BOARD_VENDOR_RAMDISK_KERNEL_MODULES into BOARD_GENERIC_RAMDISK_KERNEL_MODULES ("if there is no
# vendor boot partition, store vendor ramdisk kernel modules in the boot ramdisk") — all 341
# modules land in the generic ramdisk and init_boot.img fails at 18 MB against an 8 MB partition.
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := true
PRODUCT_BUILD_PVMFW_IMAGE := true

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# The build generates modules.load/dep/alias/softdep for the vendor_boot ramdisk, but not
# modules.blocklist — and first-stage init reads it. The shipped ramdisk carries one (60 entries,
# mostly QCOM reference-board drivers that must not auto-load); without it they would.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/kernel/vendor_dlkm-meta/modules.blocklist:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules/modules.blocklist

# fstab.default is REQUIRED in the first-stage ramdisks, and fstab.qcom is not enough.
# The bootloader sets androidboot.fstab_suffix=default (confirmed on device:
# `getprop ro.boot.fstab_suffix` -> default), so first-stage init reads fstab.default and never
# looks at fstab.qcom, despite androidboot.hardware=qcom. Shipping only fstab.qcom means there is
# no fstab at first stage, /vendor and /system never mount, and the device hangs on the Nothing
# logo with no init FATAL to catch it — which is exactly what happened on 2026-07-28 when
# vendor_boot first got built from source instead of repacked from the stock image.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.default:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.default \
    $(LOCAL_PATH)/rootdir/etc/fstab.emmc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.emmc \
    $(LOCAL_PATH)/rootdir/etc/fstab.default:$(TARGET_COPY_OUT_RAMDISK)/first_stage_ramdisk/fstab.default \
    $(LOCAL_PATH)/rootdir/etc/fstab.emmc:$(TARGET_COPY_OUT_RAMDISK)/first_stage_ramdisk/fstab.emmc

# vendor.img MUST contain the firmware mount-point directories, or nothing mounts there.
# mount_all cannot mount onto a directory that does not exist, and /vendor is read-only ext4, so
# init cannot mkdir them at runtime — they have to be baked into the image. A source-built
# vendor.img only creates directories that hold at least one file. Symptom when missing
# (seen 2026-07-28): /vendor/firmware_mnt, /vendor/dsp and /vendor/bt_firmware never mount,
# ueventd spams "firmware: attempted /vendor/firmware_mnt/image/ipa_fws.mdt, open failed", the
# ADSP/SLPI never start, and you get 1 sensor instead of 39 and no wlan0 — while the device
# otherwise boots and looks healthy.
#
# These are prebuilt_root modules in Android.bp, NOT PRODUCT_COPY_FILES: soong's fsgen turns
# PRODUCT_COPY_FILES into prebuilt_etc modules, which install under <partition>/etc and cannot
# escape upward, so a vendor/firmware_mnt/... destination fails with
# "Path is outside directory: ../firmware_mnt".
# WLAN firmware symlinks. These install_symlink modules were declared in Android.bp but never
# referenced by PRODUCT_PACKAGES, so they were dead code and never installed — /vendor/firmware/
# wlan/qca_cld/wcn7750/wlan_mac.bin and /vendor/firmware/wlanmdsp.otaupdate were simply absent,
# while stock ships both. libwifi-hal reads the MAC through that path; without it the driver load
# fails with "Failed to load WiFi driver" / "Failed to initialize firmware mode controller" and
# wlan0 never appears (found 2026-07-28).
# NOTE: firmware_WCNSS_qcom_cfg.ini_symlink is deliberately NOT added — a real WCNSS_qcom_cfg.ini
# is already installed at that path from the blob list, and both would collide.
PRODUCT_PACKAGES += \
    firmware_wlan_mac.bin_symlink \
    firmware_wlanmdsp.otaupdate_symlink

PRODUCT_PACKAGES += \
    metroid_mountpoint_firmware_mnt \
    metroid_mountpoint_dsp \
    metroid_mountpoint_bt_firmware

# Recovery init scripts
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.recovery.qcom.rc:recovery/root/init.recovery.qcom.rc

# Recovery touch. The controller keeps running without an upgrade file, but placing the stock
# firmware in the vendor ramdisk lets the source-built FocalTech driver verify/update it at probe.
PRODUCT_COPY_FILES += \
    vendor/nothing/metroid/proprietary/vendor/firmware/focaltech_ts_fw_boe.bin:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/firmware/focaltech_ts_fw_boe.bin

# NOTE on recovery adb authorization (2026-07-30): recovery's /adb_keys is a symlink to
# /product/etc/security/adb_keys, which does not exist (PRODUCT_ADB_KEYS is unset) and /product is
# not mounted in recovery mode — so recovery adb is always "unauthorized". Do NOT "fix" that with
# PRODUCT_ADB_KEYS or a PRODUCT_COPY_FILES of a developer key: this is a userdebug product, so the
# key would ship inside the public OTA zip and let that one machine adb into every user's recovery.
# For local debugging, repack the built recovery.img with a real /adb_keys instead — see
# DIAGNOSE_SIDELOAD_FAILURE.sh. Sideload itself does not need authorization.

# === b19: QCOM HAL services whose .rc is shipped as a Nothing blob but whose BINARY is
# NOT in proprietary-files.txt (init had a dangling .rc -> service never started).
# Build these from the same QCOM/AOSP sources onyx (same SoC, sun/sm8750) builds.
# (Verified absent in proprietary-files.txt: bin/hw/{thermal,usb,usb.gadget,vibrator,wifi}-service, bin/vndservicemanager.)

# Display, audio and IPA HALs are the stock Nothing binaries (proprietary-files.txt), not the
# hardware/qcom-caf/sm8750 sources: lineage-23.2 refuses a product that can install the same
# module from two namespaces, and a source-built service over stock libraries is an ABI risk.

# Stock Thermal HAL carries Nothing's shell_max mapping and thresholds. Its
# userspace shell-temperature producer is packaged as sltntc by the private
# extraction tree.
PRODUCT_PACKAGES +=     android.hardware.thermal-service.qti-nothing

# Qualcomm subsystem property aggregation service. The source module owns its
# stock-matching init and VINTF fragments; do not copy the proprietary RC alone.
PRODUCT_PACKAGES +=     vendor.qti.qspa-service

# USB + USB gadget HAL (vendor/qcom/opensource/usb/hal, default namespace)
PRODUCT_PACKAGES +=     android.hardware.usb-service.qti     android.hardware.usb.gadget-service.qti

# Nothing stock vibrator HAL with AW86938/RichTap support.
PRODUCT_PACKAGES +=     vendor.qti.hardware.vibrator.service.stock

# Vendor servicemanager (frameworks/native) - vndservice_contexts users need it
PRODUCT_PACKAGES +=     vndservicemanager

# WiFi supplicant (external/wpa_supplicant_8). The wifi HAL service is the STOCK blob
# (proprietary_force_copy.mk): the AOSP generic android.hardware.wifi-service has no vendor
# impl here ("failed to open /vendor/etc/wifi/vendor_hals") -> IWifi start fails code 9.
# Stock service + libwifi-hal (libwifi-hal-qcom/-ctrl and libcld80211 are built from
# hardware/qcom-caf/wlan, see proprietary-files.txt) + wcn7750 WCNSS_qcom_cfg.ini (icnss2 probe needs
# it or wlan0 never appears). Verified live on device 2026-07-09 (enable + multi-band scan).
# libxml2.vendor: was only installed as a dep of the removed AOSP wifi-service; qseecomd
# (libdrmfs.so) hard-requires it -> without it TEE dies -> keymint -> gatekeeper -> system_server
# crash-loop (BiometricService "Gatekeeper service not available"). Found 2026-07-09.
PRODUCT_PACKAGES +=     libxml2.vendor
PRODUCT_PACKAGES +=     wpa_supplicant     wpa_cli \
                        android.hardware.wifi.hostapd-V2-ndk
# Display HAL services come from stock (the ~23s reset was these services missing entirely).
# Their AIDL interface libraries are built from source.
PRODUCT_PACKAGES +=     android.hardware.graphics.composer3-V3-ndk.vendor     vendor.qti.hardware.display.composer3-V1-ndk.vendor     vendor.qti.hardware.display.config-V12-ndk.vendor     vendor.qti.hardware.display.aiqe-V2-ndk.vendor

# Boot control HAL from source (b20): mirror onyx device.mk
PRODUCT_PACKAGES +=     android.hardware.boot-service.qti     android.hardware.boot-service.qti.recovery \
                        libkeymaster_messages \
                        librmnetctl \
                        rmnetcli \
                        libcodec2_aidl \
                        android.hardware.radio.sim-V3-ndk \
                        android.hardware.bluetooth.finder-V1-ndk \
                        android.hardware.health-V1-ndk \
                        android.frameworks.cameraservice.common-V1-ndk \
                        android.hardware.sensors@2.1.vendor \
                        libcodec2_vndk \
                        android.hardware.radio-V2-ndk \
                        android.hardware.radio.data-V2-ndk \
                        android.hardware.radio.network-V2-ndk \
                        android.hardware.radio@1.2.vendor \
                        android.hardware.radio@1.3.vendor \
                        android.hardware.radio@1.4.vendor \
                        android.media.audio.common.types-V2-cpp


# Interface versions that stock blobs listed with DISABLE_DEPS load at runtime (ELF NEEDED of
# those blobs); soong cannot track them through the prebuilt, so install the source-built
# vendor variants explicitly.
PRODUCT_PACKAGES += \
    android.hardware.audio.core-V2-ndk.vendor \
    android.hardware.audio.core.sounddose-V1-ndk.vendor \
    android.hardware.audio.effect-V2-ndk.vendor \
    android.hardware.bluetooth.audio-V4-ndk.vendor \
    android.hardware.common-V2-ndk.vendor \
    android.hardware.common.fmq-V1-ndk.vendor \
    android.hardware.graphics.allocator-V1-ndk.vendor \
    android.hardware.graphics.allocator-V2-ndk.vendor \
    android.hardware.graphics.common-V5-ndk.vendor \
    android.hardware.security.keymint-V3-ndk.vendor \
    android.hardware.security.rkp-V3-ndk.vendor \
    android.hardware.security.secureclock-V1-ndk.vendor \
    android.hardware.security.sharedsecret-V1-ndk.vendor \
    android.hardware.thermal-V1-ndk.vendor \
    android.media.audio.common.types-V2-ndk.vendor \
    android.media.audio.common.types-V3-ndk.vendor \
    android.se.omapi-V1-ndk.vendor \
    qti-audio-types-aidl-V1-ndk.vendor \
    vendor.qti.hardware.camera.offlinecamera-V2-ndk.vendor \
    vendor.qti.hardware.display.config-V2-ndk.vendor \
    vendor.qti.hardware.display.demura-V1-ndk.vendor

# Source-built libraries that stock blobs link but that no source module pulls in: the blobs
# are listed with DISABLE_DEPS or force-copied (EXTRACT_ONLY), so soong never sees the edge.
# Missing any of these keeps a HAL in a restart loop (the audio HAL one blocks boot).
# Found with meta/scripts/check-needed.py over the build output.
PRODUCT_PACKAGES += \
    android.hardware.audio.core.sounddose-V2-ndk.vendor \
    android.hardware.sensors-V2-ndk.vendor \
    android.hardware.wifi-V2-ndk.vendor \
    lib_android_keymaster_keymint_utils.vendor \
    libalsautils.vendor \
    libalsautilsv2.vendor \
    libaudio_aidl_conversion_common_ndk.vendor \
    libbluetooth_audio_session \
    libcppbor_external.vendor \
    libhidparser \
    libkeymaster_portable.vendor \
    libmediautils_vendor.vendor \
    libmemunreachable.vendor \
    libnbaio_mono \
    libnetfilter_conntrack \
    libnfnetlink \
    libsoft_attestation_cert.vendor \
    libtinyalsav2.vendor \
    vendor.qti.hardware.display.allocator@4.0.vendor

# Inherit the proprietary vendor blobs (generated by setup-makefiles.sh)
$(call inherit-product-if-exists, vendor/nothing/metroid/metroid-vendor.mk)

# Bring-up build21: no_fatal blanket for observability (keep device up past ~29s for adb)
# /vendor/etc/fstab.default is REQUIRED, not just the ramdisk copy.
#
# /data is a `latemount`, so it is mounted by VOLD, not by first-stage init — and vold reads
# /vendor/etc/fstab.<ro.boot.fstab_suffix>, i.e. /vendor/etc/fstab.default. Until 2026-07-29 this
# tree only installed fstab.qcom there, so vold fell back to a stale blob copy with no encryption
# directives and reported ro.crypto.state=unsupported, even though the first-stage ramdisk fstab
# had the correct fileencryption= flags and /data was mounted with inlinecrypt. The FBE settings
# have to be in BOTH places.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.qcom \
    $(LOCAL_PATH)/rootdir/etc/fstab.default:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.default \
    $(LOCAL_PATH)/rootdir/etc/fstab.emmc:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.emmc \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_RAMDISK)/fstab.qcom \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_RAMDISK)/first_stage_ramdisk/fstab.qcom \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwfdaac_vendor.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwfdaac_vendor.so \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/fstab.qcom \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.qcom

# Audio policy configurations
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(LOCAL_PATH)/configs/audio/audio_module_config_primary.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_module_config_primary.xml \
    vendor/nothing/metroid/proprietary/vendor/etc/audio/sku_tuna/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    vendor/nothing/metroid/proprietary/vendor/etc/audio/sku_tuna/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    vendor/nothing/metroid/proprietary/vendor/etc/audio/sku_tuna/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml


# (bring-up ntcap/bootwatchdog boot-log capture removed 2026-07-28 — it was the single
# largest source of SELinux denials (~5000) and is not wanted in a build people flash)

# gralloc mapper VINTF fragment (standalone, matches stock layout — NOT inlined into
# manifest.xml, since AOSP libui's openDeclaredPassthroughHal only resolves standalone
# fragments under etc/vintf/manifest/, per PLAYBOOK_FROM_OPUS_20260706_MAPPER_VINTF_FIX.md).
# AOSP build rules forbid installing vintf/manifest/* via PRODUCT_COPY_FILES (build/make/core/
# Makefile hard-errors on it) — must go through the vintf_fragment soong module instead.
# mapper.qti.xml dropped 2026-07-10: qcom-caf gralloc source (mapper.qti) now provides the
# same fragment -> fsgen packaging conflict; the standalone-fragment fix was proven ineffective
# anyway (see metroid-mapper-vintf-fix-attempt-20260706).
PRODUCT_PACKAGES += camera_aon.metroid.xml
PRODUCT_PACKAGES += android.hardware.secure_element.metroid.xml
PRODUCT_PACKAGES += cacert.metroid.xml
PRODUCT_PACKAGES += hal_batch1.metroid.xml hal_batch2.metroid.xml hal_batch3.metroid.xml camera_provider.metroid.xml qms.metroid.xml mwqem.metroid.xml audio_bluetooth.metroid.xml bluetooth_audio_provider.metroid.xml media_c2.metroid.xml perf2.metroid.xml
# batch 4 (2026-07-10, live-verified): radio HALs + qspa VINTF declarations.
# clearkey dropped 2026-07-29: AOSP's own clearkey service already installs this exact fragment
# (frameworks/av/drm/mediadrm/plugins/clearkey/aidl), so ours was a duplicate installing to the
# same path. BUILD_BROKEN_DUP_RULES had been hiding it.
PRODUCT_PACKAGES += android.hardware.radio.config.metroid4.xml android.hardware.radio.data.metroid4.xml android.hardware.radio.messaging.metroid4.xml android.hardware.radio.modem.metroid4.xml android.hardware.radio.network.metroid4.xml android.hardware.radio.sim.metroid4.xml android.hardware.radio.voice.metroid4.xml
PRODUCT_PACKAGES += qti_radio_extensions.metroid.xml android.hardware.power.metroid.xml
PRODUCT_PACKAGES += vendor.noth.hardware.charge.metroid.xml
# Audio effect factory declaration (the stock effect HAL has no fragment of its own; the AGM/PAL
# declarations come from the stock manifest_audio_qti_services.xml)
PRODUCT_PACKAGES += audio_effects.metroid.xml
PRODUCT_PACKAGES += ims-ext-common ims_ext_common.xml

# Force copy missing proprietary files
$(call inherit-product-if-exists, device/nothing/metroid/proprietary_force_copy.mk)


# Force boot-time sepolicy recompile from CIL (stock prebuilt init does not honor the LOS odm precompiled)
PRODUCT_PRECOMPILED_SEPOLICY := false

# ---------------------------------------------------------------------------
# Glyph Matrix stack (ported from stock NothingOS 4.0, see GLYPH_PORT_20260720.md)
#   NtThirdParty      = com.nothing.thirdparty  -> GlyphService + toy framework (uid.system)
#   GlyphNotification = com.nothing.glyphnotification (LED-strip notifier, priv-app)
#   NothingToy/Magicball/Leveler = first-party Glyph Matrix toys
# Prebuilt modules + certificates defined in vendor/nothing/metroid/glyph/Android.mk
# ---------------------------------------------------------------------------
# PRODUCT_PACKAGES += \
#     NtThirdParty \
#     GlyphNotification \
#     NothingToy \
#     Magicball \
#     Leveler

# The Glyph apps are not installed yet (see above), so their sysconfig XML, which lived in
# logix727's private vendor tree (vendor/nothing/metroid/glyph), is not copied either.

# OPUS bring-up: EARLY (system build.prop, before zygote) props — /vendor/build.prop loads too late here.
# ro.hw_timeout_multiplier=4 -> framework Watchdog 60s*4=240s to survive the slow imageless first boot
# (odsign fails -> no boot.art -> imageless -> system_server main thread >60s -> Watchdog kill loop).
# boot_level_key.strategy: TEE keymint rejects EARLY_BOOT_ONLY (odsign Status(-8)); use MAX_USES_PER_BOOT.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.hw_timeout_multiplier=4 \
    ro.keystore.boot_level_key.strategy=TRUSTED_ENVIRONMENT:MAX_USES_PER_BOOT



# OPUS bring-up: audio HAL was BUILT but never installed (not in PRODUCT_PACKAGES) -> /vendor/bin/hw/audiohalservice.qti
# missing -> audioserver AudioFlinger::onFirstRef() null-derefs -> SoundTrigger ExternalCaptureStateTracker
# connect() LOG_ALWAYS_FATAL -> system_server crash loop. Install the core (+effect) audio HAL (soong pulls deps+VINTF).
# DO NOT comment this out again: manifest_audiocorehal_default.xml (a vintf_fragment of
# libaudiocorehal.default.so) declares android.hardware.audio.core with no server without it,
# and the failure only shows up once the prebuilt-vendor pin is gone. 2026-07-24.
# The service and libaudiocorehal.default are stock now (proprietary-files.txt); the core HAL
# VINTF fragment comes with them.
PRODUCT_PACKAGES += \
    qtiaudiohalvendorextn

DEVICE_PACKAGE_OVERLAYS += device/nothing/metroid/overlay

PRODUCT_PACKAGES += \
    CarrierConfigOverlayMetroid \
    MetroidWifiOverlay \
    MetroidTetheringOverlay \
    MetroidConnectivityOverlay \
    NTSystemUIResTarget

# Essential Key (gpio-keys scancode 250): keylayout + system_server KeyHandler that
# toggles the torch (config_deviceKeyHandlerLibs lineage-sdk overlay points at the jar).
PRODUCT_COPY_FILES += \
    device/nothing/metroid/keylayout/gpio-keys.kl:$(TARGET_COPY_OUT_SYSTEM)/usr/keylayout/gpio-keys.kl
PRODUCT_PACKAGES += MetroidKeyHandler

# Ambient display on movement: LineageOS Doze (from hardware/oplus) listening to the QTI tilt
# detector. Stock has no pickup-gesture sensor and its tap sensor type exists on no stock HAL.
PRODUCT_PACKAGES += MetroidDoze

# Sensors: the LineageOS-style multihal (from Neoteric-OS) loads the stock QSH and dynamic
# sensor sub-HALs and adds sensors.nothing: a single tap sensor (tap on the sleeping screen shows
# the ambient display) and a UDFPS long press sensor, both read from the touch driver
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.nothing-multihal \
    sensors.nothing
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/sensors/hals.conf:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/hals.conf

# Install incremental OTAs from the running system (meta/scripts/ota-apply.sh)
PRODUCT_PACKAGES_DEBUG += update_engine_client
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.metroid.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.metroid.rc


# Camera: skip Morpho EIS init in GME node (SIGILL in libmorpho_video_stabilizer on first
# frame; forces QTIGMEWrapper instead). Verified live 2026-07-10 — camera preview + capture work.
# MUST be PRODUCT_SYSTEM_PROPERTIES: /vendor/build.prop isn't loaded pre-zygote, so
# PRODUCT_VENDOR_PROPERTIES never reached runtime (empty at boot, verified 2026-07-24).
# System build.prop IS loaded early → prop actually applies.
PRODUCT_SYSTEM_PROPERTIES += persist.vendor.morpho.eis.force_gmenode=1

# Populate vendor_dlkm + system_dlkm with the stock kernel modules (empty = hard reset ~7-9s).
include $(LOCAL_PATH)/dlkm_modules.mk

# Optional private branding (overlays, names, wallpapers): $(CUSTOM_BRANDING_DIR)/config/branding.mk
# Set by meta/scripts/build.sh for BRANDING=1 (meta/manifests/smk.xml); unset builds plain LineageOS.
ifneq ($(CUSTOM_BRANDING_DIR),)
$(call inherit-product-if-exists, $(CUSTOM_BRANDING_DIR)/config/branding.mk)
endif
