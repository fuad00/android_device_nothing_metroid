# Generated makefile to force copy missing proprietary blobs
PRODUCT_COPY_FILES += \
    vendor/nothing/metroid/proprietary/system_ext/etc/permissions/extphonelib.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/extphonelib.xml \
    vendor/nothing/metroid/proprietary/system_ext/etc/permissions/qti_telephony_hidl_wrapper.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/qti_telephony_hidl_wrapper.xml \
    vendor/nothing/metroid/proprietary/system_ext/etc/permissions/qti_telephony_utils.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/qti_telephony_utils.xml \
    vendor/nothing/metroid/proprietary/system_ext/lib64/android.hidl.base@1.0.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/android.hidl.base@1.0.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/libencoderjpeg_jni.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libencoderjpeg_jni.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/libqcomfm_jni.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libqcomfm_jni.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/libqti_vndfwk_detect_system.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libqti_vndfwk_detect_system.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/libvndfwk_detect_jni.qti_system.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/libvndfwk_detect_jni.qti_system.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/vendor.qti.hardware.capabilityconfigstore@1.0.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.hardware.capabilityconfigstore@1.0.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/vendor.qti.hardware.display.composer@3.0.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.hardware.display.composer@3.0.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/vendor.qti.hardware.display.composer@3.1.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.hardware.display.composer@3.1.so \
    vendor/nothing/metroid/proprietary/system_ext/lib64/vendor.qti.hardware.perf@2.3.so:$(TARGET_COPY_OUT_SYSTEM_EXT)/lib64/vendor.qti.hardware.perf@2.3.so \
    vendor/nothing/metroid/proprietary/vendor/apex/com.google.android.widevine-12498615.apex:$(TARGET_COPY_OUT_VENDOR)/apex/com.google.android.widevine-12498615.apex \
    vendor/nothing/metroid/proprietary/vendor/etc/aidl/le_audio/aidl_audio_set_configurations.json:$(TARGET_COPY_OUT_VENDOR)/etc/aidl/le_audio/aidl_audio_set_configurations.json \
    vendor/nothing/metroid/proprietary/vendor/etc/aidl/le_audio/aidl_audio_set_scenarios.json:$(TARGET_COPY_OUT_VENDOR)/etc/aidl/le_audio/aidl_audio_set_scenarios.json \
    vendor/nothing/metroid/proprietary/vendor/etc/init/android.hardware.drm-service.clearkey.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.drm-service.clearkey.rc \
    vendor/nothing/metroid/proprietary/vendor/etc/permissions/advancedSample_camera_extensions.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/advancedSample_camera_extensions.xml \
    vendor/nothing/metroid/proprietary/vendor/etc/permissions/android.hardware.hardware_keystore.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.hardware_keystore.xml \
    vendor/nothing/metroid/proprietary/vendor/etc/res/images/default/charger/battery_fail.png:$(TARGET_COPY_OUT_VENDOR)/etc/res/images/default/charger/battery_fail.png \
    vendor/nothing/metroid/proprietary/vendor/etc/res/images/default/charger/battery_scale.png:$(TARGET_COPY_OUT_VENDOR)/etc/res/images/default/charger/battery_scale.png \
    vendor/nothing/metroid/proprietary/vendor/etc/richtapresources/notification/oi!.he:$(TARGET_COPY_OUT_VENDOR)/etc/richtapresources/notification/oi!.he \
    vendor/nothing/metroid/proprietary/vendor/lib64/android.hardware.common-V2-ndk_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.common-V2-ndk_platform.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/android.hardware.security.sharedsecret-V2-ndk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/android.hardware.security.sharedsecret-V2-ndk.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libvndfwk_detect_jni.qti_vendor.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libvndfwk_detect_jni.qti_vendor.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwfdaac_vendor.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwfdaac_vendor.so \
    vendor/nothing/metroid/proprietary/vendor/product/media/audio/notifications/01_oi.ogg:$(TARGET_COPY_OUT_VENDOR)/product/media/audio/notifications/01_oi.ogg \


# === METROID audio-only tranche (2026-07-09) — sound path; no VINTF decl, low boot risk ===
PRODUCT_COPY_FILES += \
    vendor/nothing/metroid/proprietary/vendor/bin/audioadsprpcd:$(TARGET_COPY_OUT_VENDOR)/bin/audioadsprpcd \

# === METROID wifi + missing-libs tranche (2026-07-09, Fable) ===
# 1) stock wifi HAL service (AOSP generic has no vendor impl) + libs + wcn7750 driver cfg
# 2) NDK/dep libs absent from this build but required by shipped blobs:
#    radio-V3-ndk -> qcrilNrd (CELL), wifi.common-V1-ndk -> wifi HAL,
#    cameraservice.common-V1-ndk -> noth camera ext, libtinycompress+closure -> audio HAL/PAL.
# All verified live on device via /vendor/lib64 overlay before staging.
PRODUCT_COPY_FILES += \
    vendor/nothing/metroid/proprietary/vendor/bin/hw/android.hardware.wifi-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.wifi-service \
    vendor/nothing/metroid/proprietary/vendor/etc/init/android.hardware.wifi-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.wifi-service.rc \
    vendor/nothing/metroid/proprietary/vendor/etc/wifi/wcn7750/WCNSS_qcom_cfg.ini:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wcn7750/WCNSS_qcom_cfg.ini \
    vendor/nothing/metroid/proprietary/vendor/firmware/wlan/qca_cld/wcn7750/WCNSS_qcom_cfg.ini:$(TARGET_COPY_OUT_VENDOR)/firmware/wlan/qca_cld/wcn7750/WCNSS_qcom_cfg.ini \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwifi-hal.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwifi-hal.so \

# bluetooth: STOCK BT HAL rc (packaged rc had bring-up `disabled` -> IBluetoothHci declared
# but never served -> BT stack stuck BLE_TURNING_ON->OFF). Verified live: BT state ON w/ address.
PRODUCT_COPY_FILES += \
    vendor/nothing/metroid/proprietary/vendor/etc/init/android.hardware.bluetooth@aidl-service-qti.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.bluetooth@aidl-service-qti.rc

# BISECT 2026-07-25: init.qti.display_boot.sh REMOVED from this
# (ipacm RESTORED 2026-07-25: its Android.bp also ships the tetheroffload VINTF fragment, so
#  removing the binary left android.hardware.tetheroffload IOffload/default DECLARED WITH NO
#  SERVER -- a guaranteed servicemanager stall. Never drop a blob whose module owns a fragment.)
# list -- it is absent from the known-booting vendor, and force-copying it in makes
# previously-dangling services actually run (display_boot.sh alone sets ~25 vendor.display.* props).
# NB: never comment a line out inside a `\` continuation list -- make joins lines first, so the '#'
# swallows every following entry in the block. Delete the line instead.
# dangling-rc sweep RE-ADD (2026-07-10; first added 07-09, lost in known-good revert):
# services whose .rc ships but binary didn't. ipacm=IPA tethering/offload, clearkey DRM,
# hlosminkdaemon (TEE mink), display_boot script.
PRODUCT_COPY_FILES += \
    vendor/nothing/metroid/proprietary/vendor/bin/ipacm:$(TARGET_COPY_OUT_VENDOR)/bin/ipacm \
    vendor/nothing/metroid/proprietary/vendor/bin/hlosminkdaemon:$(TARGET_COPY_OUT_VENDOR)/bin/hlosminkdaemon \
    vendor/nothing/metroid/proprietary/vendor/bin/hw/android.hardware.drm-service.clearkey:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.drm-service.clearkey \
    vendor/nothing/metroid/proprietary/vendor/bin/init.qcom.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.qcom.sh \
    vendor/nothing/metroid/proprietary/vendor/bin/init.qcom.post_boot.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.qcom.post_boot.sh \
    vendor/nothing/metroid/proprietary/vendor/bin/init.qcom.sdio.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.qcom.sdio.sh \
    vendor/nothing/metroid/proprietary/vendor/bin/vendor_modprobe.sh:$(TARGET_COPY_OUT_VENDOR)/bin/vendor_modprobe.sh \
    vendor/nothing/metroid/proprietary/vendor/bin/cnss_diag:$(TARGET_COPY_OUT_VENDOR)/bin/cnss_diag \
    vendor/nothing/metroid/proprietary/vendor/bin/hw/android.hardware.security.keymint-service-spu-qti:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.security.keymint-service-spu-qti \
    vendor/nothing/metroid/proprietary/vendor/bin/hw/android.hardware.security.keymint-service.strongbox-thales:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.security.keymint-service.strongbox-thales \
    vendor/nothing/metroid/proprietary/vendor/bin/hw/vendor.noth.hardware.charge-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/vendor.noth.hardware.charge-service \
    vendor/nothing/metroid/proprietary/vendor/bin/hw/vendor.qti.hardware.memtrack-service:$(TARGET_COPY_OUT_VENDOR)/bin/hw/vendor.qti.hardware.memtrack-service \
    vendor/nothing/metroid/proprietary/vendor/bin/nt_ddr_test:$(TARGET_COPY_OUT_VENDOR)/bin/nt_ddr_test \
    vendor/nothing/metroid/proprietary/vendor/bin/qttestclient:$(TARGET_COPY_OUT_VENDOR)/bin/qttestclient \
    vendor/nothing/metroid/proprietary/vendor/bin/qttestservice:$(TARGET_COPY_OUT_VENDOR)/bin/qttestservice \
    vendor/nothing/metroid/proprietary/vendor/bin/spu_install_keybox:$(TARGET_COPY_OUT_VENDOR)/bin/spu_install_keybox \
    vendor/nothing/metroid/proprietary/vendor/bin/wifidisplayhalservice:$(TARGET_COPY_OUT_VENDOR)/bin/wifidisplayhalservice \
    vendor/nothing/metroid/proprietary/vendor/etc/camera/metroid_smoothzoom_config.json:$(TARGET_COPY_OUT_VENDOR)/etc/camera/metroid_smoothzoom_config.json \
    vendor/nothing/metroid/proprietary/vendor/lib64/hw/android.hardware.bluetooth.audio_sw.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/android.hardware.bluetooth.audio_sw.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/hw/libaudiocorehal.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/libaudiocorehal.default.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/hw/libaudiocorehal.qti.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/libaudiocorehal.qti.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/hw/libaudioeffecthal.qti.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/libaudioeffecthal.qti.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libaudioplatformconverter.qti.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudioplatformconverter.qti.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libjc_keymint-thales.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libjc_keymint-thales.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/liblogwrap.so:$(TARGET_COPY_OUT_VENDOR)/lib64/liblogwrap.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/liboffloadhal.so:$(TARGET_COPY_OUT_VENDOR)/lib64/liboffloadhal.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libqapesdk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libqapesdk.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libqcodec2_core.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libqcodec2_core.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libqtigefar.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libqtigefar.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libqtnodes.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libqtnodes.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libqttestclient.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libqttestclient.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libspukeymint.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libspukeymint.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libspukeymintprovision.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libspukeymintprovision.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwfdmmsrc_proprietary.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwfdmmsrc_proprietary.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwfdsessionmodule.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwfdsessionmodule.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwfdsourcesession_proprietary.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwfdsourcesession_proprietary.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/libwfdsourcesm_proprietary.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwfdsourcesm_proprietary.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/soundfx/libqcompostprocbundle.so:$(TARGET_COPY_OUT_VENDOR)/lib64/soundfx/libqcompostprocbundle.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/soundfx/libqcomvisualizer.so:$(TARGET_COPY_OUT_VENDOR)/lib64/soundfx/libqcomvisualizer.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/soundfx/libqcomvoiceprocessing.so:$(TARGET_COPY_OUT_VENDOR)/lib64/soundfx/libqcomvoiceprocessing.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/soundfx/libvolumelistener.so:$(TARGET_COPY_OUT_VENDOR)/lib64/soundfx/libvolumelistener.so \
    vendor/nothing/metroid/proprietary/vendor/lib64/vendor.qti.hardware.wifidisplaysessionl@1.0-halimpl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/vendor.qti.hardware.wifidisplaysessionl@1.0-halimpl.so
