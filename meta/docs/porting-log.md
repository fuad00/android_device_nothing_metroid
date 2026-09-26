# Журнал портирования на lineage-23.2

Каждая правка — отдельный коммит с объяснением «почему».

## Подготовка (26.09.2026)

- Бэкап всех разделов, кроме userdata/super/rawdump, + GPT каждого LUN: `scripts/backup-partitions.sh`.
  Ловушка: в `/dev/block/by-name` есть ссылки `sda`…`sdf` на **целые LUN** — первая версия скрипта начала
  копировать весь `sda` (с userdata) в `/data` и заполнила его. Теперь `sd[a-z]` пропускаются.

## Сборка (26.09.2026)

| Ошибка сборки | Причина | Исправление |
|---|---|---|
| `libqti_vndfwk_detect`: partition is different | блоб дублировал модуль из `hardware/qcom-caf/common` | из «замыкания» зависимостей убраны всё, что собирается из исходников (`libqti_vndfwk_detect`, `libPeripheralStateUtils`, `libar-gsl`*, `libvmmem`) |
| `libar-gsl` из исходников: нет `ar_osal_types.h` | генератор списка сравнивал строки FroggerPro с хвостовым пробелом — `libar-gsl.so ` и `libthermalclient.so ` «не нашлись» и выпали | `rstrip()`; оба снова блобы |
| `proc_sched_walt` unknown type | убрал `include hardware/nothing/config.mk` | вернул: он подключает common sepolicy и namespace, пакетные части условны |
| host_init_verifier: `vendor.charge-default-poweroff` без user | стоковый `init.nt_product.rc` | фиксап `user root` (как у стока) |
| touch-drivers: `No targets` | нет Makefile-обёртки для inline-сборки | cherry-pick AmphibianArcade «qcom: touch-drivers: Fix inline build» |
| `focaltech_tp`: No rule for `focaltech_core.o` | в Kbuild Nothing пути без `focaltech_tp/` (Bazel этого не видит) | префикс в Kbuild (форк modules) |
| `tls.ko from SYSTEM_KERNEL_MODULES was not found` | в gki_defconfig TLS не модулем, сток грузит tls.ko | `CONFIG_TLS=m` в `vendor/Metroid.config` |
| depmod: `msm_drm` unknown symbol `hdcp*`/`smmu_proxy_*` в vendor ramdisk | display собран отдельно от securemsm → modinfo не называет зависимости | `hdcp_qseecom_dlkm`, `smmu_proxy_dlkm` явно в `modules.load.recovery` |
| `vendor_boot.img too large (248 MB)` | merge_dtbs склеил все деревья sun/kera/tuna (517 шт.) | `TARGET_MERGE_DTBS_WILDCARD := tuna`, `TARGET_MERGE_DTBOS_WILDCARD := tuna-*` |

Проверки v1: ядро `6.6.127-fuad00` (`fuad00@fuad00-lineage`); dtb `tuna` = сток (кроме `gpu_cc_memnoc_gfx_clk`), overlay
`tuna-qrd` = сток по содержимому (без учёта phandle/номеров фрагментов); 25 образов firmware = сток B4.1 побайтно; vbmeta Flags 0.

## Первая установка v1 (26.09.2026) — не загрузилась

- **Virtual A/B: полный OTA из recovery забирает весь `super`.** Слот a (LineageOS, ~3,7 ГБ) лёг на экстенты слота b
  (сток B4.1, ~7 ГБ): метаданные b остались, данные перезаписаны → сток в b разрушен, «страховочный слот» не работает.
  (Тот же урок, что на OnePlus: super не вмещает обе системы.) Проверка — `lpdump` по первым 1 МБ `super`.
- **`adb reboot sideload`** пишет команду в `misc` (BCB); если выйти из recovery не штатно, каждая загрузка уходит в sideload.
  Штатный выход из меню recovery её стирает.
- **Recovery LineageOS: кнопка питания не работает** — minui открывает 16 устройств ввода, у metroid датчик сжатия даёт 13
  (`aw9380x_0_ch*`), power оказывается за пределом. Исправлено форком `bootable/recovery` (патч logix727, 32 устройства).
- **Загрузчик:** слот, который ABL не смог загрузить, сразу помечается `unbootable` без расхода `retry-count`. После
  перезагрузки по dm-verity ABL показывает красный «device is corrupt» и включает `veritymode=eio` для этой ОС
  (строки ABL: «New OS instance detected - changing from 'eio' to 'restart' mode»).
- `fastboot flash vbmeta_a --disable-verity` на маке падает («Failed to find AVB_MAGIC at offset 0»); флаг
  HASHTREE_DISABLED ставится вручную: байты 120..123 заголовка `vbmeta` = `00 00 00 01`.
- **pvmfw** не входил в firmware zip → в слоте a остался V3.5 рядом с hyp/tz B4.1. Добавлен в `proprietary-firmware.txt`
  (сам по себе причиной не оказался).
- **Симптом v1:** логотип → жёлтое предупреждение → логотип (ядро стартует) → перезагрузка; с verity и без. Данные слота a
  побайтно = сборке. `fastboot boot` нашего ядра со стоковым `vendor_boot` слота b проходит дальше (до dm-verity).
  → подозрение на наш `vendor_boot` (dtb/модули первой стадии/cmdline). pstore пуст: `qcom_dynamic_ramoops` у стока
  грузится только из `vendor_dlkm` → теперь первым в vendor ramdisk.
- **Сборка logix727 (lineage-23.0) загружается** (их bootstrap-образы извлечены из payload их zip: boot, init_boot,
  vendor_boot, dtbo, recovery, pvmfw, vbmeta* в оба слота; `fastboot -w`; sideload). У них: ядро — стоковое GKI
  `6.6.127-android15-8-g1a9b880d342b` (prebuilt), vbmeta `Flags: 1`, свой pvmfw, dtb — tuna+tuna7+tunap, dtbo — 12 overlay.
  Эталон рабочей загрузки (модули, свойства, logcat) — `~/Downloads/nothing_phone_3/logs/logix727/`.

## Этап 1: ядро из исходников на сборке logix727 (26.09.2026) — работает

- **Сборка.** Kleaf, как у Nothing: `//common:kernel_aarch64` (AOSP `1a9b880d342b`, тот же коммит, из которого Google собрал
  стоковый GKI B4.1) + NothingOSS msm-kernel `sm8735/b/mr` (форк `fuad00/android_kernel_msm-6.6_nothing_sm8735`).
  Идентичность — коммитами в форке `build/kernel`: `6.6.127-android15-8-fuad00-4k (fuad00@fuad00-lineage)`.
  Правки: `qbt_handler`, `spcom`, `spss_utils` в B4.1 объявлены только для вариантов gki/consolidate — добавлен perf;
  ST NFC (`stm_nfc_i2c`, `stm_st54se_gpio`) собирается из `st/opensource` форка sm8735-modules (logix727 брал их из стока);
  «exported twice» в modpost — патч logix727 (дедупликация `Module.symvers`) коммитом в `build/kernel`.
  Модули и `modules.dep` против стока B4.1: совпадают все, кроме `cqhci` и устаревшего `tls.ko` (стоковый — от 6.6.102).
  dtb/dtbo (`build_tuna_dtb.sh` logix727) — байт в байт как у logix727.
- **Тупик: ветка `sm8735/v/mr` (6.6.57).** Модули расходятся со стоком в 119 модулях; logix727 записал, что такие модули
  отвергаются на первой стадии. Сохранена как `lineage-23.2-v657`, не используется.
- **`init_user0_failed` — не модули, а AVB-свойства boot.** Тестовый `boot.img` переподписан без свойств футера
  (`com.android.build.boot.security_patch` и др.) → загрузчик отдаёт KeyMint другой boot patch level → KeyMint не
  открывает существующие ключи: `vold: decryptWithKeystoreKey failed`, `keystore2` SIGABRT → recovery. С перенесёнными
  свойствами загружается. `fastboot boot` берёт свойства из прошитого `boot_a`, поэтому шаг А (прошит был boot logix727)
  прошёл. В настоящей сборке свойства ставит система сборки; урок — не терять свойства при ручной переупаковке.
- **Логи при раннем сбое** есть в разделе `nt_kmsg` (64 МБ, модуль Nothing `nothing_writeback_kmsg` пишет туда kmsg
  нескольких последних загрузок): `adb exec-out 'dd if=/dev/block/by-name/nt_kmsg'` из recovery. pstore пуст.
- **Только ядро без своих модулей** (`fastboot boot`, модули logix727): GKI-модули из `system_dlkm` подписаны ключом
  Google и нашим ядром не грузятся (кроме zram) → нет Bluetooth/звука; ядро и модули нужно ставить одним комплектом.
- Итог: Wi-Fi, Bluetooth, звук, камера, NFC-драйвер работают; 60 Гц и FRP — проблемы пользовательской части logix727.
