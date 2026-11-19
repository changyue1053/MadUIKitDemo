"""Compile dependency: verify receipts and source identity before Kotlin compilation."""
import subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
codegen=Path(sys.argv[1]).resolve(strict=True)
inputs=root/'binding-inputs'; bundle=root/'verified-bundle'
subprocess.run([sys.executable,str(codegen/'scripts/generate-verified.py'),'--verify-only','--input',str(inputs/'snapshot.json'),'--node','10:1','--out',str(bundle),'--flatten-instances','--component-map',str(inputs/'binding.json'),'--font-map',str(inputs/'font.json')],check=True)
source=root/'composeApp/src/iosMain/kotlin/dev/maduikit/demo/generated/FigmaProfileScreen.generated.kt'
assert not source.is_symlink() and source.read_bytes()==(bundle/'FigmaProfileScreen.generated.kt').read_bytes()
print('PASS: exact verified typed component + font generated source before compiler')
