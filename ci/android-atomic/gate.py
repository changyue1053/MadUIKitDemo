from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1];b=root/'ci-evidence/android-atomic/bundle'
m=json.loads((b/'manifest.json').read_text());d=json.loads((b/'diagnostics.json').read_text())
assert d['ok'] is True and d['errors']==[] and d['inputSha256']==m['inputSha256']
for name,sha in m['files'].items():
 p=b/name;assert p.is_file() and not p.is_symlink() and hashlib.sha256(p.read_bytes()).hexdigest()==sha
 target=root/'composeApp/src/commonMain'/ ('kotlin/dev/maduikit/demo/generated/'+name if name.endswith('.kt') else name)
 assert target.read_bytes()==p.read_bytes()
print('Atomic consumer gate: exact verified source and packaged resource input bytes.')
