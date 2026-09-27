#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

import os

from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)
from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.fixups_lib import (
    lib_fixups,
    lib_fixups_user_type,
)


def lib_fixup_vendor_suffix(lib: str, partition: str, *args, **kwargs):
    return f'{lib}_{partition}' if partition == 'vendor' else None


def stock_vendor_libs():
    # Libraries listed with MODULE_SUFFIX=_vendor: stock copies that coexist with a source
    # module of the same name; vendor users must link the stock copy.
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'proprietary-files.txt')
    names = []
    for line in open(path):
        line = line.split('#')[0].strip()
        if 'MODULE_SUFFIX=_vendor' in line and line.split(';')[0].endswith('.so'):
            names.append(os.path.basename(line.split(';')[0])[:-3])
    return tuple(names)


STOCK_ABI_LIBS = (
    'libtinyxml2',
    'libjsoncpp',
    'libxml2',
    'libchrome',
    'libflatbuffers-cpp',
    'libaudioserviceexampleimpl',
    'libaudioutils',
    'libbluetooth_audio_session_aidl',
    'android.hardware.bluetooth.audio-impl',
)


def stock_abi_users():
    # stock-abi-users.txt (meta/scripts/gen-stock-abi.py): blobs that must keep the stock copy
    # of a C++ library whose ABI differs from the source build
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stock-abi-users.txt')
    users = {}
    for line in open(path):
        fields = line.split('#')[0].split()
        if len(fields) > 1:
            users[fields[0]] = fields[1:]
    return users


def lib_fixup_stock_abi(lib: str, partition: str, *args, **kwargs):
    return f'{lib}_system_ext' if partition == 'system_ext' else lib


lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
    stock_vendor_libs(): lib_fixup_vendor_suffix,
    tuple(f'{lib}-stock' for lib in STOCK_ABI_LIBS): lib_fixup_stock_abi,
    # hardware/qcom-caf/wlan also has a wifihal_qcom_defaults named libwifi-hal-qcom; point
    # stock users at the library itself
    'libwifi-hal-qcom': lambda *args, **kwargs: '//hardware/qcom-caf/wlan/qcwcn:libwifi-hal-qcom',
}

namespace_imports = [
    'hardware/qcom-caf/sm8750',
    'hardware/qcom-caf/wlan',
    'hardware/qcom-caf/wlan/qcwcn',
    'vendor/qcom/opensource/commonsys/display',
    'vendor/qcom/opensource/commonsys-intf/display',
    'vendor/qcom/opensource/dataservices',
    'vendor/qcom/opensource/display',
    'device/nothing/metroid',
]

blob_fixups: blob_fixups_user_type = {
    # Satellite (NTN) and QCC libraries were built against the stock protobuf; give them that copy
    ('system_ext/lib64/libQmsNtnProto.so', 'system_ext/lib64/libqms_ntnsatellite_sdk.so'): blob_fixup()
        .replace_needed('libprotobuf-cpp-lite.so', 'libprotobuf-cpp-lite-stock.so'),
    'system_ext/lib64/vendor.qti.hardware.qccsyshal@1.2-halimpl.so': blob_fixup()
        .replace_needed('libprotobuf-cpp-full.so', 'libprotobuf-cpp-full-stock.so'),
    # Voice activation libraries need stock TFLite's XNNPack delegate
    (
        'vendor/lib64/libVoiceSdk.so',
        'vendor/lib64/libcapiv2uvvendor.so',
        'vendor/lib64/liblistensoundmodel2vendor.so',
    ): blob_fixup()
        .replace_needed('libtensorflowlite_c.so', 'libtensorflowlite_c-stock.so'),
    # Declared as XML 2.0; the build parses permission files and accepts only XML 1.0
    'system_ext/etc/permissions/vendor.qti.hardware.c2pa-V1-java.xml': blob_fixup()
        .regex_replace('<\\?xml version="2.0"', '<?xml version="1.0"'),
    # Installed next to (not over) hardware/qcom-caf/thermal's module of the same name
    'vendor/etc/init/android.hardware.thermal-service.qti-nothing.rc': blob_fixup()
        .regex_replace('/vendor/bin/hw/android.hardware.thermal-service.qti\n',
                       '/vendor/bin/hw/android.hardware.thermal-service.qti-nothing\n'),
    'vendor/etc/init/android.hardware.biometrics.face-service.noth.rc': blob_fixup()
        .regex_replace('    disabled\n    disabled\n', '    disabled\n')
        .regex_replace(
            '    group camera system\n',
            '    group camera system\n'
            '    interface aidl android.hardware.biometrics.face.IFace/default\n',
        ),
    'vendor/etc/init/cnd.rc': blob_fixup()
        .regex_replace('    disabled\n', ''),
    'vendor/etc/init/qms.rc': blob_fixup()
        .regex_replace('    disabled\n', '')
        .regex_replace(
            '     class main\n',
            '     class main\n'
            '     user root\n',
        )
        .regex_replace('    user root\n    group root\n', ''),
    'vendor/etc/init/init.nt_logtool.rc': blob_fixup()
        .regex_replace(
            'service diag_gpslog_start ',
            'on post-fs-data\n'
            '    mkdir /data/vendor/diag_mdlog 0770 root system\n'
            '    restorecon_recursive /data/vendor/diag_mdlog\n\n'
            'service diag_gpslog_start ',
        ),
    'system_ext/etc/init/perfservice.rc': blob_fixup()
        .regex_replace(
            'service vendor.perfservice /system_ext/bin/perfservice\n'
            '    class main\n'
            '    user system\n'
            '    group system readproc\n\n',
            '',
        ),
    'vendor/etc/init/hw/init.qcom.usb.rc': blob_fixup()
        .regex_replace('ncm\\.0', 'ncm.gs6'),
    'vendor/etc/init/hw/init.qcom.rc': blob_fixup()
        .regex_replace(
            '    exec u:r:vendor_qti_init_shell:s0 -- /vendor/bin/init\\.qti\\.can\\.sh\n',
            '',
        )
        .regex_replace(
            'service nqnfcinfo /system/vendor/bin/nqnfcinfo\n'
            '    class late_start\n'
            '    group nfc\n'
            '    user system\n'
            '    oneshot\n\n',
            '',
        )
        .regex_replace(
            'service ptt_socket_app /system/vendor/bin/ptt_socket_app -d\n'
            '    class main\n'
            '    user wifi\n'
            '    group wifi system inet net_admin\n'
            '    capabilities NET_ADMIN\n'
            '    oneshot\n\n',
            '',
        )
        .regex_replace(
            'service qvop-daemon /vendor/bin/qvop-daemon\n'
            '    class late_start\n'
            '    user system\n'
            '    group system drmrpc\n\n',
            '',
        )
        .regex_replace(
            'service qseeproxydaemon /system/vendor/bin/qseeproxydaemon\n'
            '    class late_start\n'
            '    user system\n'
            '    group system\n\n',
            '',
        )
        .regex_replace(
            'service vendor\\.atfwd /vendor/bin/ATFWD-daemon\n'
            '    class late_start\n'
            '    user system\n'
            '    group system radio\n\n',
            '',
        )
        .regex_replace(
            'service esepmdaemon /system/vendor/bin/esepmdaemon\n'
            '    class core\n'
            '    user system\n'
            '    group nfc\n\n',
            '',
        )
        .regex_replace(
            'service chre /vendor/bin/chre\n'
            '    class late_start\n'
            '    user system\n'
            '    group system\n'
            '    socket chre seqpacket 0660 root system\n'
            '    shutdown critical\n\n'
            'on property:vendor\\.chre\\.enabled=0\n'
            '   stop chre\n\n',
            '',
        ),
    'vendor/etc/init/vendor.qti.hardware.perf2-hal-service.rc': blob_fixup()
        .regex_replace('    disabled\n    disabled\n', ''),
    'vendor/etc/init/vendor.qti.media.c2@1.0-service.rc': blob_fixup()
        .regex_replace('    disabled\n', ''),
    'vendor/etc/init/vendor.qti.media.c2audio@1.0-service.rc': blob_fixup()
        .regex_replace('    disabled\n', ''),
}

for path, libs in stock_abi_users().items():
    fixup = blob_fixups.get(path, blob_fixup())
    for lib in libs:
        fixup = fixup.replace_needed(f'{lib}.so', f'{lib}-stock.so')
    blob_fixups[path] = fixup

module = ExtractUtilsModule(
    'metroid',
    'nothing',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
)

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()
