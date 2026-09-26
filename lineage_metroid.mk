#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_product.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_product.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_system_ext.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_vendor.mk)

$(call inherit-product, device/nothing/metroid/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_BRAND := Nothing
PRODUCT_DEVICE := metroid
PRODUCT_MANUFACTURER := Nothing
PRODUCT_MODEL := A024
PRODUCT_NAME := lineage_metroid

PRODUCT_GMS_CLIENTID_BASE := android-nothing

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="qssi_64-user 16 BQ2A.250721.001-BP2A.250605.031.A3 2608141733 release-keys" \
    BuildFingerprint=Nothing/Metroid/Metroid:16/BQ2A.250721.001-BP2A.250605.031.A3/2608141733:user/release-keys \
    DeviceName=Metroid \
    DeviceProduct=Metroid \
    SystemDevice=Metroid \
    SystemName=Metroid
