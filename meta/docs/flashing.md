# Бэкап, сток и прошивка

Серийник Nothing — в каждой команде `-s`, ниже `$S` (на маке подключён и OnePlus 10 Pro — его не трогаем).
Каждый шаг — после явного «ок»; телефон переводит в нужный режим владелец.

## 1. Бэкап уникальных разделов

Нужен root. Без записи во флеш: ядро стока + ramdisk из `init_boot`, пропатченного Magisk, загружаются в память.

```bash
# на телефоне (Android): патч стокового init_boot той же сборки
adb -s $S push <magisk-lib-и-assets> init_boot.img /data/local/tmp/mp/
adb -s $S shell 'cd /data/local/tmp/mp && KEEPVERITY=true KEEPFORCEENCRYPT=true sh boot_patch.sh init_boot.img'
# на маке: boot-образ v4 = ядро из boot.img + ramdisk из new-boot.img
python3 unpack_bootimg.py --boot_img boot.img --out b; python3 unpack_bootimg.py --boot_img new-boot.img --out ib
python3 mkbootimg.py --header_version 4 --kernel b/kernel --ramdisk ib/ramdisk --output boot_magisk.img
# bootloader:
fastboot -s $S boot boot_magisk.img
# после загрузки (подтвердить su на экране):
meta/scripts/backup-partitions.sh $S ~/Downloads/nothing_phone_3/device_dumps/<дата>_<сборка>
```

Первый бэкап: `device_dumps/2026-09-26_V3.5-250923-1421/` (129 файлов, 4,6 ГБ).

## 2. Обновление стока (полный OTA → неактивный слот)

```bash
meta/scripts/stock-ota-update.sh $S ~/Downloads/nothing_phone_3/stock/B4.1-260814-1733/Metroid_B4.1-260814-1733.zip
```

`update_engine` пишет всё (включая firmware) в неактивный слот и делает его активным; подпись payload
проверяет сам телефон. После «UPDATED_NEED_REBOOT» — `adb -s $S reboot`. Если новый слот не загрузится,
загрузчик после исчерпания попыток вернётся в старый.

## Откат

- Полный сток любой сборки — образы из `stock/<сборка>/images` (sha256 из архива spike0en).
- Уникальные разделы — из `device_dumps/…` (только при реальной порче, по отдельному решению).
