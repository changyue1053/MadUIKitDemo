import importlib.util,json,hashlib,subprocess,sys,shutil
from pathlib import Path
codegen,evidence=map(Path,sys.argv[1:]);root=Path.cwd()
spec=importlib.util.spec_from_file_location('fixture',codegen/'scripts/atomic-frame-smoke.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
fixture=evidence/'fixture';fixture.mkdir()
leaf=[dict(id=i,type='VECTOR',absoluteBoundingBox=m.bbox(*r),fills=[m.fill]) for i,r in zip(m.vector_ids,m.rectangles)]
f=m.layer(m.frame_id,'FRAME',16,12,'NONE',leaf);o=m.layer(m.owner_id,'INSTANCE',16,12,'HORIZONTAL',[f]);o['componentId']='82:1';doc=m.layer(m.root_id,'FRAME',40,24,'VERTICAL',[o])
png=m.payload();(fixture/'mad_icon_synthetic_bars.png').write_bytes(png)
(fixture/'data.json').write_text(json.dumps({'version':'synthetic-bars','nodes':{m.root_id:{'document':doc}}}))
(fixture/'map.json').write_text(json.dumps(dict(schemaVersion=2,nodeId=m.frame_id,framePath=[m.root_id,m.owner_id,m.frame_id],vectorIds=m.vector_ids,file='mad_icon_synthetic_bars.png',sha256=hashlib.sha256(png).hexdigest())))
subprocess.run([sys.executable,str(codegen/'scripts/generate-verified.py'),'--launcher',str(codegen/'build/install/MadUIKitCodegen/bin/MadUIKitCodegen'),'--input',str(fixture/'data.json'),'--asset-map',str(fixture/'map.json'),'--node',m.root_id,'--flatten-instances','--out',str(evidence/'bundle')],check=True)
bundle=evidence/'bundle'; common=root/'composeApp/src/commonMain'
shutil.copyfile(bundle/'FigmaProfileScreen.generated.kt',common/'kotlin/dev/maduikit/demo/generated/FigmaProfileScreen.generated.kt')
shutil.copytree(bundle/'composeResources',common/'composeResources')
p=root/'composeApp/build.gradle.kts';s=p.read_text().replace('implementation(compose.ui)','implementation(compose.ui)\n            implementation(compose.components.resources)');s+='\ncompose.resources { packageOfResClass = "dev.maduikit.demo.resources" }\n';p.write_text(s)
# Replace the gradient-specific gate only in the isolated CI checkout with a strict atomic gate.
shutil.copyfile(root/'ci/android-atomic/gate.py',root/'scripts/verify-codegen-consumer.py')
p=common/'kotlin/dev/maduikit/demo/DemoScreen.kt';p.write_text('''package dev.maduikit.demo
import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mad.maduikit.MadTheme
import dev.maduikit.demo.generated.FigmaProfileScreen
@Composable fun DemoScreen() { MadTheme(darkTheme=false) { Column(Modifier.fillMaxSize().background(Color.White).padding(24.dp)) { Text("MadUIKit atomic PNG") ; Spacer(Modifier.height(24.dp)); FigmaProfileScreen() } } }
''')
