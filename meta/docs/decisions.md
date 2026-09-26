# Решения

| Дата | Решение | Почему |
|---|---|---|
| 2026-09-26 | Сток-база — **Nothing OS B4.1-260814-1733** (Android 16), телефон обновляется до неё | Все живые деревья metroid и ядро HELLBOY017 — на 4.x; блобы Android 16 ближе к lineage-23.2; блобы берём строго той версии, что стоит на телефоне |
| 2026-09-26 | `TARGET_ARCH_VARIANT`/`TARGET_CPU_VARIANT` — как у wly (`armv8-a-branchprot` / `generic`), а не `armv8-2a-dotprod` как у sm8750 | Дерево и `out/soong` общие с OnePlus; другой вариант удвоил бы промежуточные файлы (~35 ГБ) |
| 2026-09-26 | Бэкап — через `fastboot boot` ядра стока + Magisk-ramdisk (без записи во флеш) | Самый обратимый способ получить root |
| 2026-09-26 | Обновление стока — `update_engine_client` с полным OTA в неактивный слот | Официальный механизм: подпись payload проверяет телефон, при неудаче загрузчик возвращается в старый слот |
| 2026-09-26 | Освобождено место на сервере (OnePlus: `/root/stock`, `/root/release`, `archive/…/old_trees`, `release/stock-901-os` — есть в Releases, `stock/901` — есть zip) | 35 → 67 ГБ |
| 2026-09-26 | База device-дерева — **AmphibianArcade/android_device_nothing_FroggerPro** (Phone (4a) Pro, та же платформа `sun`, lineage-23.2), адаптированная под metroid | Самое чистое 23.2-дерево Nothing на sun; блоки, init и fstab почти совпадают со стоком metroid (1779 из 1869 блобов есть у metroid). Всё устройство-зависимое заменено стоком B4.1 metroid |
| 2026-09-26 | Ядро, модули, dtb/dtbo — из исходников: форки **HELLBOY017/kernel_nothing_sm8735{,-modules,-devicetrees}** (ветка `lineage-23.2`), сборка как у официального `oneplus/sm8750-common` (`BOARD_USES_QCOM_MERGE_DTBS_SCRIPT`, `TARGET_NEEDS_DTBOIMAGE`) | У FroggerPro dtb/dtbo — prebuilt; ядро HELLBOY017 уже разложено под сборку LineageOS и содержит Nothing B4.0 |
| 2026-09-26 | `hardware/nothing` — ветка AmphibianArcade (в форке `fuad00/android_hardware_nothing`, ветка `lineage-23.2`; вариант LineageOS сохранён в `lineage-23.2-lineageos`) | Их AIDL-обёртка отпечатка умеет LHBM (оптический UDFPS на sun); из пакетов берём только HAL отпечатка |
| 2026-09-26 | Датчики — AOSP multihal из исходников + стоковые sub-HAL; вибрация — QTI HAL из исходников; Glyph, FeliCa, DeviceExtras — не включены | Для первой загрузки — минимум непроверенного на metroid кода |
| 2026-09-26 | AVB без `--flags 3` (FroggerPro отключал проверку) | Иначе libavb не передаёт `androidboot.vbmeta.*` (урок OnePlus: HAL отпечатка читает `device_state`) и закрыт путь к `avb_custom_key` |

## Выбор базы device-дерева и ядра

Кандидаты (разбор 26.09.2026, чтение репозиториев через `gh api`):

| Кандидат | База | Обновлён | Ядро | Блобы | Вывод |
|---|---|---|---|---|---|
| logix727/android_device_nothing_metroid | lineage-23.0 | 2026-08-24 | prebuilt GKI + модули/dtb из исходников Nothing отдельным Kleaf | B4.1-260414 (vendor-репо приватный) | грузится (enforcing, данные, IMS, камера, UDFPS); ~40 патчей AOSP, `WITH_DEXPREOPT := false`, MTK-токены в cmdline. Источник знаний, не база |
| oddlyspaced (Evolution X QPR2) | форк logix727 | 2026-09-09 | так же | B4.1-260814 | только собирается |
| Eddie07 (lineage-23.2) | шаблон `device/qcom/sun` | 2026-09-25 | форк logix727 | ? | слишком рано |
| carloslfu, PHATWalrus (_los + vendor) | 23.0 / «23.2» | 07–09.2026 | prebuilt | B4.1-260624 | permissive, камера/отпечаток не работают — нет |
| twrpdtgen, Farpathan, SavedByLight, DrBrown28 | recovery | — | prebuilt | twrpdtgen: ветка V3.5-250923-1421 | справка |
| **HELLBOY017/kernel_nothing_sm8735{,-modules,-devicetrees}** (`lineage`) | ядро | 2026-09-23 | CLO 6.6 + патчи LineageOS + Nothing B4.0-251117, `vendor/Metroid.config` | — | **ядро** |
| AmphibianArcade/android_kernel_nothing_sm8750{,-modules} (23.2) | ядро | 2026-09-06 | LineageOS sm8750 + драйверы Nothing, `metroid_perf.config` | — | запасной вариант ядра |
| **AmphibianArcade/android_device_nothing_FroggerPro** (Phone (4a) Pro, `sun`, lineage-23.2) + `android_hardware_nothing` | 23.2 | 2026-09-26 | из исходников | FroggerPro B4.1 | **шаблон структуры** |

Ориентиры: официальные `oneplus/sm8750-common` + `dodge` (23.2), `nothing/Spacewar`, `nothing/Pong`
(ядро из исходников, Glyph, отпечаток), `hardware/nothing`; тот же SoC — `xiaomi-onyx-dev/android_device_xiaomi_onyx` (POCO F7, 23.2).
