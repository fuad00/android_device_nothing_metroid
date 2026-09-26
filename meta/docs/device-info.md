# Инвентаризация (26.09.2026)

## Телефон

| | |
|---|---|
| Модель | Nothing Phone (3), A024, `Metroid`, SKU ROW (`vendor.sku=tuna`) |
| SoC | SM8735 (Snapdragon 8s Gen 4), `ro.board.platform=sun`, загрузчик `00265-PAKALA-1`, fastboot `product: sun` |
| Сток на момент начала | Nothing OS 3.5 `V3.5-250923-1421`, Android 15 (AQ3A.250226.002), SPL 2025-09-01, vendor SPL 2025-03-05 |
| Ядро стока | 6.6.57-android15-8 GKI |
| Экран | 1260×2800, 480 dpi; панель `qcom,mdss_dsi_rm692j0_120hz_fhd_plus_dsc_cmd` |
| Память | DDR 12 ГБ, UFS: userdata 224 ГиБ, super 9 ГиБ |
| Разделы | A/B, dynamic partitions, Virtual A/B (compression), `init_boot`, `vendor_boot` v4, `vbmeta_system`/`vbmeta_vendor` |
| Загрузчик | `unlocked: yes`, `critical unlocked: no`, `secure: yes`, `fuse-state: PROD FUSE`; `fastboot boot` работает |
| Device tree | SM8735 = Qualcomm **tuna** (семейство sun): стоковый загрузчик выбирает dtb `Tuna SoC` (msm-id `0x28f`, `dtb_idx=10` в V3.5) и overlay `Tuna QRD` (board-id `0xb`, `dtbo_idx=72`) — Nothing правит референсный QRD. В B4.1 dtbo — 127 overlay (`meta/scripts/dtinfo.py`) |
| bootconfig стока | `dtb_idx=10`, `dtbo_idx=72`, `hwid_version=PVT`; UEFI передаёт в cmdline `haptic.uefi_f0`/`uefi_f0_calidata`; `erofs.reserved_pages=128` |

Размеры разделов — `fastboot getvar all` (на маке `inventory/`).

## Состояние, в котором телефон пришёл

- Уже был root: `init_boot_a` — стоковый `init_boot` сборки 250829-1700, пропатченный Magisk 30.6
  (модули Shamiko, ADB Root Enabler, MagiskFrida, MoveCertificate, Systemless Hosts).
- **Shamiko подменяет свойства**: Android показывал `ro.boot.flash.locked=1`, `verifiedbootstate=green`,
  `vbmeta.device_state=locked`, хотя в `/proc/bootconfig` — `orange` / `unlocked`. Сравнивать с «эталоном
  стока» можно только bootconfig, не getprop.
- Слот a: firmware — побайтно V3.5-250923; `boot`, `vendor_boot`, `dtbo`, `recovery` — стоковые 250829
  (сверены с `vbmeta_a`; инкрементальный OTA их не переписывал). Слот b: старая firmware, `unbootable`.

## Стоковые образы

Nothing не публикует fastboot-образы. Полные OTA и распакованные из них образы — архив spike0en:
`https://archive.org/download/nothing-archive/spike0en/fullota/metroid/Metroid_<build>.zip` и
`https://github.com/spike0en/nothing_archive/releases/tag/Metroid_<build>` (7z по группам + sha256).

| Сборка | Android | SPL | Полный OTA |
|---|---|---|---|
| V3.5-250923-1421 | 15 | 2025-09-01 | 6,55 ГБ, md5 `f4fed51a…` |
| B4.0-251117-1909 | 16 | 2025-11 | 6,70 ГБ |
| **B4.1-260814-1733** (выбрана) | 16 (BP2A), SDK 36 | 2026-08-01 | 7,31 ГБ, md5 `8acabd35075cee0ca745c7480fb34d4d` |
| C5.0-260819 (бета) | 17 | — | только инкрементальный |

## Anti-rollback

- Firmware: у всех подписанных MBN v7 образов метаданные подписи (включая поля ARB) в V3.5-250923 и
  B4.1-260814 совпадают побайтно — обновление не поднимает ARB, откат firmware на V3.5 не блокируется.
- AVB rollback-индексы (vbmeta_system / vbmeta_vendor = дата SPL): V3.5 2025-09-01/2025-03-05,
  B4.1 2026-08-01/2026-04-05; у верхнего vbmeta 0. Имеют значение только при заблокированном загрузчике.

## Исходники

- Ядро Nothing: `NothingOSS/android_kernel_msm-6.6_nothing_sm8735` — один монолитный репозиторий
  (dts, techpack, модули). `sm8735/v/mr` = V3.5 (6.6.57), `sm8735/b/mr` = до B4.1-260814 (6.6.127).
- Официального LineageOS для SM8735 нет. Ближайшая платформа — SM8750 («pakala»): OnePlus 13 `dodge`,
  `oneplus/sm8750-common`, `kernel_oneplus_sm8750{,-modules,-devicetrees}`, CAF — ветки
  `lineage-23.2-caf-sm8750`.

## avb_custom_key

Поддерживается: Phone (3) в списке устройств avbroot (chenxiaolong/avbroot#299), перезаблокировка с
собственным ключом описана на V3.5-250923-1421 (avbroot#554). Нюансы: стоковый recovery собран с
`dev-keys` (sideload release-keys OTA отвергается), загрузчик не передаёт
`androidboot.vbmeta.public_key_digest`, first-stage fstab в `vendor_boot` принимает для DSU только GSI-ключи.
Решение о блокировке — после стабильной загрузки, отдельно.
