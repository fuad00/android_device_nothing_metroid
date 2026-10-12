# LineageOS 23.2 for the Nothing Phone (3) (metroid)

Unofficial LineageOS 23.2 (Android 16) for the Nothing Phone (3), model A024, codename `metroid`
(Snapdragon 8s Gen 4 / SM8735, platform `sun`). The repository root is the device tree
(`device/nothing/metroid`); build tooling, manifests and notes live in [`meta/`](meta/).

Based on the metroid tree by [logix727](https://github.com/logix727/android_device_nothing_metroid),
whose history is kept here.

## Status

Working: display at 120 Hz, touch, in-display fingerprint, PIN/pattern lock, Wi-Fi, Bluetooth
(A2DP offload), audio and audio effects, calls and mobile data, NFC, GPS (with XTRA), camera,
sensors, always-on display with a pulse when the phone is moved, tap to wake, encryption,
SELinux enforcing, OTA updates.

Known issues: eSIM is not detected (the modem reports the embedded slot as empty). The boot
logo before the boot animation is Nothing's own (it lives in signed bootloader firmware).

Builds: `user`, signed with the maintainer's own release keys, from
[Releases](../../releases).

## Installation

The build is made on top of stock **Nothing OS B4.1-260814-1733** firmware. The firmware
partitions (abl, xbl, tz, modem, dsp, …) are not in the zip, so both slots must carry B4.1
firmware before installing — update stock Nothing OS to B4.1 first. An older firmware (e.g.
V3.5) in either slot breaks radio, audio and keystore.

1. Unlock the bootloader (wipes the phone).
2. Make sure both slots run B4.1 firmware (update stock, or flash the B4.1 firmware images to
   both slots, as the Nothing fastboot packages do).
3. Flash the recovery from Releases: `fastboot flash recovery_a recovery.img` and
   `fastboot flash recovery_b recovery.img`, then `fastboot reboot recovery`.
4. In recovery: Factory reset → Format data, then Apply update → Apply from ADB and
   `adb sideload lineage-23.2-*-metroid.zip` (join the `.partNN` pieces first:
   `cat lineage-*.zip.part* > lineage.zip`, check with `shasum -a 256 -c SHA256SUMS`).
5. Reboot.

Updates: full zips through recovery as above; incremental zips only from the running system
(on Virtual A/B, recovery refuses incremental sideloads).

## Building

- Sync LineageOS 23.2 and add [`meta/manifests/metroid.xml`](meta/manifests/metroid.xml) as a
  local manifest (device tree plus the forks it needs).
- Kernel: built from Nothing's GPL release with Kleaf, see [`meta/kernel/`](meta/kernel/)
  (`build-kernel.sh`, then `stage-kernel.sh` into `kernel/out/`).
- Proprietary files: `./extract-files.py <stock B4.1 OTA dump>` generates `vendor/nothing/metroid`.
- Build: [`meta/scripts/build.sh`](meta/scripts/build.sh) (`VARIANT=user DEBUG=0` for release
  builds); [`meta/scripts/check-needed.py`](meta/scripts/check-needed.py) and
  [`check-symbols.py`](meta/scripts/check-symbols.py) verify that every stock blob finds its
  libraries and symbols.

## Credits

LineageOS, Nothing (kernel sources and firmware), logix727 (original metroid bring-up), the
OnePlus SM8450 LineageOS team (Doze), chenxiaolong (avbroot research).

## License

Apache License 2.0, see [LICENSE](LICENSE). Proprietary blobs belong to their owners and are
not part of this repository.
