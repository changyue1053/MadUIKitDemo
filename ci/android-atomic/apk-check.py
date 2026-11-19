from pathlib import Path
import zipfile,json,sys,hashlib
out=Path(sys.argv[1]);m=json.loads((out/'bundle/manifest.json').read_text());a=m['decorativeAsset'];expected=(out/'bundle'/a['file']).read_bytes()
with zipfile.ZipFile(out/'public-synthetic-demo.apk') as z:
 found=[n for n in z.namelist() if n.endswith('/'+Path(a['file']).name)]
 assert len(found)==1 and z.read(found[0])==expected,found
(out/'apk-resource-proof.json').write_text(json.dumps({'entry':found[0],'sha256':hashlib.sha256(expected).hexdigest(),'exact':True},indent=2))
