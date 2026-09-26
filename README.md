# SMK OS (LineageOS 23.2) для Nothing Phone (3) — A024, metroid

Монорепозиторий порта: device-дерево (корень репозитория, чекаутится в `device/nothing/metroid`)
и мета-часть в `meta/` — манифест, скрипты, документы, результаты тестов. Релизы (zip, образы) — в
GitHub Releases этого репозитория.

Ядро собирается из исходников (отдельный форк), blobs извлекаются из стокового OTA на сервере,
их копия — в отдельном приватном репозитории, не здесь.

## Устройство

Nothing Phone (3), A024, `metroid`, SM8735 (Snapdragon 8s Gen 4, платформа `sun`), ядро 6.6 GKI,
Virtual A/B со сжатием, экран 1260×2800 @ 480 dpi. Подробно — [meta/docs/device-info.md](meta/docs/device-info.md).

## Где что лежит

| | |
|---|---|
| Сервер сборки | `root@<build-server>`, дерево LineageOS — общее с OnePlus: `/root/oneplus_10_pro_lineage/lineage` (свой local manifest `metroid.xml`) |
| — свои скрипты, логи, сток | `/root/nothing_phone_3/{scripts,logs,stock}` |
| Мак | `~/Downloads/nothing_phone_3/` — этот репозиторий в `nothing_phone_3_lineage/`, сток в `stock/`, дампы телефона в `device_dumps/` (**не коммитить**: IMEI/EFS/persist) |

Файлы больше 50 МБ между сервером и маком не копируем по scp — через GitHub Releases.
Сборка на сервере одна за раз (`pgrep -af "[s]oong_ui"`). Все команды adb/fastboot — только с `-s <серийник>`:
на том же маке подключён OnePlus 10 Pro.

## Документы

- [meta/docs/decisions.md](meta/docs/decisions.md) — решения и их причины
- [meta/docs/device-info.md](meta/docs/device-info.md) — инвентаризация телефона и стока
- [meta/docs/porting-log.md](meta/docs/porting-log.md) — журнал проблем и исправлений
- [meta/docs/flashing.md](meta/docs/flashing.md) — бэкап, обновление стока, прошивка
- [meta/docs/test-matrix.md](meta/docs/test-matrix.md) — проверка железа
- [meta/docs/logix727-lessons.md](meta/docs/logix727-lessons.md) — уроки чужого бринг-апа metroid
