"""Generate and verify exactly one public snapshot; never rewrite generated source."""
import hashlib, json, shutil, subprocess, sys
from pathlib import Path
codegen, consumer, evidence = map(Path, sys.argv[1:4])
state = sys.argv[4]
assert state in ('enabled', 'disabled')
inputs = consumer / 'binding-inputs'
if inputs.exists(): shutil.rmtree(inputs)
inputs.mkdir()
fixture = codegen/'fixtures/figma/component-binding'
snapshot = json.loads((fixture/('snapshot.json' if state == 'enabled' else 'disabled.json')).read_text())
snapshot['nodes']['10:1']['document']['children'][0]['children'][0]['style']['fontFamily'] = 'Synthetic Brand'
(inputs/'snapshot.json').write_text(json.dumps(snapshot, indent=2)+'\n')
shutil.copyfile(fixture/'binding.json', inputs/'binding.json')
(inputs/'font.json').write_text(json.dumps(dict(schemaVersion=1,mappings=[dict(family='Synthetic Brand',role='body')]),indent=2)+'\n')
bundle=consumer/'verified-bundle'
if bundle.exists(): shutil.rmtree(bundle)
command=[sys.executable,str(codegen/'scripts/generate-verified.py'),'--launcher',str(codegen/'build/install/MadUIKitCodegen/bin/MadUIKitCodegen'),'--input',str(inputs/'snapshot.json'),'--node','10:1','--out',str(bundle),'--flatten-instances','--component-map',str(inputs/'binding.json'),'--font-map',str(inputs/'font.json')]
subprocess.run(command,check=True)
subprocess.run(command+['--verify-only'],check=True)
source=bundle/'FigmaProfileScreen.generated.kt'
target=consumer/'app/src/main/kotlin/dev/maduikit/demo/generated/FigmaProfileScreen.generated.kt'
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(source,target)
assert target.read_bytes()==source.read_bytes()
evidence.mkdir(parents=True,exist_ok=True)
shutil.copytree(bundle,evidence/'bundle')
shutil.copytree(inputs,evidence/'inputs')
(evidence/'source.sha256').write_text(hashlib.sha256(source.read_bytes()).hexdigest()+'\n')
