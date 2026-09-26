#!/usr/bin/env python3
"""Generate proprietary-files.txt for metroid: FroggerPro's list filtered to what exists in the
metroid B4.1 dump, plus whole device-specific directories, plus the ELF NEEDED closure."""
import os, re, subprocess, sys
D='/root/nothing_phone_3/stock/Metroid_B4.1-260814-1733'
SRC='/tmp/pf_frogger.txt'
def src_of(line):
    return line.lstrip('-').split(';')[0].split(':')[0].split('|')[0]
def exists(p): return os.path.lexists(os.path.join(D,p))
out=[]; kept=set(); dropped=[]
for l in open(SRC):
    l=l.rstrip('\n')
    if not l.strip() or l.startswith('#'):
        out.append(l); continue
    s=src_of(l)
    if exists(s): out.append(l); kept.add(s)
    else: dropped.append(l)
out[0:2]=['## All proprietary files from this list, unless pinned and noted otherwise,',
          '## are from the B4.1-260814-1733 release for the Nothing Phone (3) (metroid).']
def walk(prefix):
    base=os.path.join(D,prefix); res=[]
    if os.path.isfile(base) or os.path.islink(base): return [prefix]
    for r,ds,fs in os.walk(base):
        for f in fs+[d for d in ds if os.path.islink(os.path.join(r,d))]:
            res.append(os.path.relpath(os.path.join(r,f),D))
    return sorted(res)
sections=[
 ('Camera (metroid)', ['vendor/lib64/camera','vendor/etc/camera']),
 ('Audio calibration (metroid)', ['vendor/etc/acdbdata','vendor/etc/lvacfs_params']),
 ('Sensors (metroid)', ['vendor/etc/sensors']),
 ('Firmware (metroid)', ['vendor/firmware']),
 ('Media (tuna)', ['vendor/etc/media_tuna_v0','vendor/etc/media_tuna_v1']),
 ('Init (metroid)', ['vendor/etc/init/hw/init.nt_product.rc','vendor/etc/init/hw/init.qcom.factory.rc',
                     'vendor/etc/init/hw/init.qti.kernel.rc','vendor/etc/init/hw/init.qti.kernel.target.rc',
                     'vendor/etc/init/hw/init.qti.ufs.rc','vendor/bin/init.kernel.post_boot.sh',
                     'vendor/bin/init.kernel.post_boot-memory.sh','vendor/bin/init.qti.kernel.sh']
                    +[f for f in walk('vendor/bin') if re.search(r'/init\.(kernel\.post_boot|qti\.kernel\.(early_)?debug)-(sun|tuna)',f)]),
]
# never ship what the tree builds or installs itself
skip=re.compile(r'(firmware/wlan/qca_cld/wcn7750/(wlan_mac\.bin|WCNSS_qcom_cfg\.ini)$|firmware/wlanmdsp\.otaupdate$)')
added=[]
for title,paths in sections:
    items=[]
    for p in paths:
        for f in walk(p):
            if f in kept or skip.search(f): continue
            items.append(f); kept.add(f)
    if items:
        out+=['',f'# {title}']+items; added+=items
# ELF NEEDED closure over vendor libs present in the dump
def needed(path):
    try: o=subprocess.run(['readelf','-dW',path],capture_output=True,text=True).stdout
    except Exception: return []
    return re.findall(r'\(NEEDED\).*\[(.+?)\]',o)
vlib={}
for f in walk('vendor/lib64'):
    vlib.setdefault(os.path.basename(f),[]).append(f)
PROPRIETARY=re.compile(r'^(libarcsoft|libmotiondetection|libstmobile|libPeripheralStateUtils|libar-gsl|libvmmem|libqti_vndfwk_detect|librender_lib)')
closure=[]; queue=[k for k in kept if k.startswith(('vendor/','odm/'))]
seen=set()
while queue:
    k=queue.pop()
    if k in seen: continue
    seen.add(k)
    p=os.path.join(D,k)
    if os.path.islink(p) or not os.path.isfile(p): continue
    with open(p,'rb') as fh:
        if fh.read(4)!=b'\x7fELF': continue
    for n in needed(p):
        cands=[c for c in vlib.get(n,[]) if c.count('/')==2]  # vendor/lib64/<lib>
        for c in cands:
            if c not in kept and PROPRIETARY.match(os.path.basename(c)):
                kept.add(c); closure.append(c); queue.append(c)
if closure:
    out+=['','# Dependencies (metroid, ELF NEEDED closure; review)']+sorted(closure)
open('/tmp/proprietary-files.metroid.txt','w').write('\n'.join(out)+'\n')
open('/tmp/pf_dropped.txt','w').write('\n'.join(dropped)+'\n')
print('kept from frogger',len([l for l in out if l and not l.startswith('#')])-len(added)-len(closure),'dropped',len(dropped),'added dirs',len(added),'closure',len(closure))
print('\n'.join(sorted(closure)))
