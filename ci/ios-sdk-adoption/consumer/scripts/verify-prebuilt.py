"""Xcode phase: verify the exact independently linked framework, never invoke Gradle."""
import hashlib,json,os,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
print('XCODE FRAMEWORK VERIFY START',flush=True)
receipt=json.loads((root/'prebuilt-framework.json').read_text())
assert os.environ.get('CONFIGURATION')=='Debug','Debug simulator only'
assert os.environ.get('SDK_NAME')==receipt['sdkName'],'Unexpected Xcode SDK'
assert os.environ.get('ARCHS','').strip()=='x86_64','Intel simulator only'
base=root/'composeApp/build/xcode-frameworks/Debug'/receipt['sdkName']/'MadUIKitDemoShared.framework'
actual={str(p.relative_to(base)):hashlib.sha256(p.read_bytes()).hexdigest() for p in base.rglob('*') if p.is_file()}
assert actual and actual==receipt['files'],'Missing/changed prebuilt framework'
print('XCODE FRAMEWORK VERIFY PASS: '+str(len(actual))+' files',flush=True)
