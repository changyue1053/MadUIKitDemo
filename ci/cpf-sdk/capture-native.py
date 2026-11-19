#!/usr/bin/env python3
"""Capture an already verified same-link pair; no host, signing or private data."""
import argparse, hashlib, json, os, re, shutil, subprocess
from pathlib import Path

def capture(binary, out, env):
    binary, out = Path(binary), Path(out)
    if out.exists(): raise ValueError('refusing existing capture output')
    for key in ('GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'):
        if not re.fullmatch('[a-f0-9]{40}' if key == 'GITHUB_SHA' else '[1-9][0-9]*', env.get(key,'')):
            raise ValueError('invalid CI identity: '+key)
    files = ('libkn.so', 'libkn_api.h')
    for name in files:
        p=binary/name
        if p.is_symlink() or not p.is_file() or not p.stat().st_size: raise ValueError('invalid native input '+name)
    elf=subprocess.check_output(['readelf','-h',str(binary/'libkn.so')],text=True)
    symbols=subprocess.check_output(['readelf','--dyn-syms','--wide',str(binary/'libkn.so')],text=True)
    if not re.search(r'Type:\s+DYN',elf) or not re.search(r'Machine:\s+AArch64',elf): raise ValueError('wrong native architecture/type')
    if not any(len(x:=line.split())>=8 and x[6]!='UND' and x[7]=='MainArkUIViewController' for line in symbols.splitlines()): raise ValueError('controller export missing')
    if 'MainArkUIViewController' not in (binary/'libkn_api.h').read_text(): raise ValueError('controller declaration missing')
    out.mkdir()
    for name in files: shutil.copyfile(binary/name,out/name)
    sha={name:hashlib.sha256((out/name).read_bytes()).hexdigest() for name in files}
    receipt={'schema':1,'repository':'changyue1053/MadUIKitDemo','commit':env['GITHUB_SHA'],'run':env['GITHUB_RUN_ID'],'attempt':env['GITHUB_RUN_ATTEMPT'],'sdkCommit':'19c8c1b1fbe75b7d6a6118fdab42048948de091b','upstreamCommit':'a049930ec7d874f292427288d5389acf4f98ed3b','kotlin':'2.2.21-1.2.0','compose':'1.9.2-1.2.0','backend':'skia','abi':'ohos_arm64','sha256':sha,'status':'native-link-only; partial-linkage warnings remain; no HAP or runtime'}
    data=json.dumps(receipt,indent=2,sort_keys=True)+'\n'
    (out/'provenance.json').write_text(data)
    print('CAPTURE_PROVENANCE_SHA256='+hashlib.sha256(data.encode()).hexdigest())
    print(data)
    return receipt

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bin',required=True);p.add_argument('--out',required=True);a=p.parse_args()
    capture(a.bin,a.out,os.environ)
