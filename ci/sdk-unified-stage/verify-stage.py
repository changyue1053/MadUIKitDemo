"""Verify a once-produced SDK publication without touching Gradle or importing archives."""
import hashlib, json, re, sys, zipfile
from pathlib import Path
stage=Path(sys.argv[1]); base=stage/'com/mad/maduikit'; ver='0.1.0-alpha01'
def require(ok,reason):
 if not ok:raise ValueError(reason)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths=list(stage.rglob('*'))
require(paths and all(not p.is_symlink() and (p.is_file() or p.is_dir()) for p in paths),'unsafe stage')
files={str(p.relative_to(stage)):sha(p) for p in sorted(paths) if p.is_file()}
require(files and all(n.startswith('com/mad/maduikit/') for n in files),'non-SDK paths')
targets={'android':('aar','releaseApiElements-published','releaseRuntimeElements-published'),'iossimulatorarm64':('klib','iosSimulatorArm64ApiElements-published'),'iosarm64':('klib','iosArm64ApiElements-published')}
require({p.name for p in base.iterdir()}=={f'maduikit-{mod}'+('-'+t if t else '') for mod in ('components','theme') for t in ('',*targets)},'unexpected module inventory')
leafs={}
for mod in ('components','theme'):
 name='maduikit-'+mod
 root=base/name/ver
 def readmod(p,n):return json.loads((p/f'{n}-{ver}.module').read_text())
 r=readmod(root,name); require((r['component']['group'],r['component']['module'],r['component']['version'])==('com.mad.maduikit',name,ver),'root coordinate')
 for target,(ext,*variants) in targets.items():
  leaf=f'{name}-{target}'; folder=base/leaf/ver; file=folder/f'{leaf}-{ver}.{ext}'
  n=readmod(folder,leaf); h=sha(file)
  require((folder/(file.name+'.sha256')).read_text().strip()==h,'leaf SHA sidecar')
  for vn in variants:
   rv,=[v for v in r['variants'] if v['name']==vn]
   at=rv['available-at']; require((at['group'],at['module'],at['version'])==('com.mad.maduikit',leaf,ver),'root redirect coordinate')
   require((root/at['url']).resolve()==(folder/f'{leaf}-{ver}.module').resolve(),'root redirect path')
   v,=[v for v in n['variants'] if v['name']==vn]
   entry,=[x for x in v['files'] if x['url']==file.name]
   require((entry['sha256'],entry['size'])==(h,file.stat().st_size),'module leaf mismatch')
   if ext=='klib':
    expect='ios_arm64' if target=='iosarm64' else 'ios_simulator_arm64'
    require(v['attributes']['org.jetbrains.kotlin.native.target']==expect,'variant native target')
    with zipfile.ZipFile(file) as z:
     require(z.namelist().count('default/manifest')==1 and z.testzip() is None,'invalid KLIB')
     props=dict(x.split('=',1) for x in z.read('default/manifest').decode().splitlines())
    require(props['native_targets']==expect and props['compiler_version']=='2.2.21' and props['short_name']==name,'KLIB target/identity')
   else:
    require(v['attributes']['org.jetbrains.kotlin.platform.type']=='androidJvm','variant Android target')
    with zipfile.ZipFile(file) as z:
     require(z.namelist().count('classes.jar')==1 and z.testzip() is None,'invalid AAR')
  leafs[leaf]={'sha256':h,'size':file.stat().st_size}
require(len({v['sha256'] for v in leafs.values()})==6,'aliased leaves')
print(json.dumps(dict(version=ver,leafs=leafs,files=files),indent=2,sort_keys=True))
