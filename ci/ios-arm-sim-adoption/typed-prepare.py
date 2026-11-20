"""Restore exact prior public typed source and bundles without building Codegen."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

SDK_PIN="19c8c1b1fbe75b7d6a6118fdab42048948de091b"
CODEGEN_PIN="7276d8f3843a91ec5394e527fcbd1a63ad99a712"
DEMO_PROBE="060fd852f61d742e79f1963d11621739a90af6fc"
WRAPPER_SHA="4384de555fabe96d5f2fc8ccce2da3be26d2b3d2f6e81aa25822bf29fcfb5dfd"
GENERATED="FigmaProfileScreen.generated.kt"
SOURCE_HASH={
 "enabled":"44a8dad7ec063a81609088a435275959065bb0069b0e258349a8a656a8559311",
 "disabled":"6d2018c0dac29e0e7b76e85a4910b83cfc1bccd75fe3d4fd9efbcab786761579",
}
APP_BUNDLE="dev.mad.adoption.ios.typedfilter"
TEST_BUNDLE="dev.mad.adoption.ios.typedfilter.uitests"
NEW_TARGET="MadUIKitTypedFilter"
XCTEST=f"{NEW_TARGET}UITests/TypedFilterUITests/testGeneratedBinding"

sha=lambda b:hashlib.sha256(b).hexdigest()
def need(c,m):
    if not c:raise ValueError(m)

def transform(root, state):
    def update(f,replacements):
        data=f.read_text()
        for old,new,mincount in replacements:
            need(data.count(old)>=mincount,"Retained typed source pattern changed")
            data=data.replace(old,new)
        f.write_text(data)
    proj=root/"iosApp/MadUIKitDemo.xcodeproj"
    ios=root/"iosApp"
    pbx=proj/"project.pbxproj"
    scheme=proj/"xcshareddata/xcschemes/MadUIKitDemo.xcscheme"
    for path in (pbx,scheme):
        update(path,[("47524718","54595045",4),("MadUIKitDemo",NEW_TARGET,6)])
    update(pbx,[("BookFilterUITests.swift","TypedFilterUITests.swift",1),
                ("dev.maduikit.demo.uitests",TEST_BUNDLE,2)])
    scheme.rename(scheme.with_name(NEW_TARGET+".xcscheme"))
    proj.rename(proj.with_name(NEW_TARGET+".xcodeproj"))
    update(ios/"Demo.xcconfig",[("dev.mad.adoption.ios",APP_BUNDLE,1),("MadUIKit Demo","MadUIKit Typed Filter",1)])
    test=ios/"BookFilterUITests.swift"
    update(test,[("BookFilterUITests","TypedFilterUITests",1),
                 ("dev.mad.adoption.ios",APP_BUNDLE,1),("EXPECT_ENABLED",str(state=="enabled").lower(),1)])
    test.rename(test.with_name("TypedFilterUITests.swift"))
    update(root/"settings.gradle.kts",[("IndependentIosBooks","IndependentIosTypedFilter",1)])
    update(root/"composeApp/build.gradle.kts",[("iosX64","iosSimulatorArm64",2),
                ("iosx64","iossimulatorarm64",3),("ios_x64","ios_simulator_arm64",1)])
    update(root/"scripts/verify-prebuilt.py",[("'x86_64'","'arm64'",1),("Intel simulator only","Apple Silicon simulator only",1)])
    verifier=root/"scripts/verify-generated.py"
    s=verifier.read_text()
    need(s.count("source.read_bytes()")==1,"Unexpected original verification shape")
    verifier.write_text(s.replace("import subprocess,sys","import hashlib,subprocess,sys",1)+
        f"\nif source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != '{SOURCE_HASH[state]}':\n"
        "    raise SystemExit('Generated source differs from pinned native evidence')\n")


def materialize(checkout, codegen, output):
    actual=lambda p:subprocess.check_output(["git","-C",str(p),"rev-parse","HEAD"],text=True).strip()
    need(actual(checkout)==DEMO_PROBE and actual(codegen)==CODEGEN_PIN,"Typed source checkout pins mismatch")
    source=checkout/"ci/ios-typed-consumer/consumer"
    fixture=Path(__file__).with_name("typed-fixtures.json").read_bytes()
    need(sha(fixture)=="ab26dc3f508368645f0fbfdd6df85fffd90b1d016c4bdb0dec1964c3f69f11ef","Typed synthetic fixtures drifted")
    fixture=json.loads(fixture)
    docs={p.relative_to(source).as_posix():p for p in source.rglob("*") if p.is_file()}
    need(docs.keys()==fixture["typedSourceBlobs"].keys() and not any(p.is_symlink() for p in source.rglob("*")),
         "Unexpected typed source closure")
    for name,path in docs.items():
        data=path.read_bytes()
        need(hashlib.sha1(f"blob {len(data)}\0".encode()+data).hexdigest()==fixture["typedSourceBlobs"][name],
             "Typed public source blob mismatch")
    wrapper=codegen/"scripts/generate-verified.py"
    need(sha(wrapper.read_bytes())==WRAPPER_SHA,"Pinned Codegen verifier changed")
    for state,wanted in SOURCE_HASH.items():
        dest=output/("typed-"+state)
        need(not dest.exists(),"Typed consumer work directory already exists")
        shutil.copytree(source,dest)
        transform(dest,state)
        for name,data in fixture["states"][state].items():
            prefix,leaf=name.split("/")
            target=dest/{"inputs":"binding-inputs","bundle":"verified-bundle"}[prefix]/leaf
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(data.encode("utf8"))
        bundle=dest/"verified-bundle"/GENERATED
        need(sha(bundle.read_bytes())==wanted,"Exact generated source changed")
        manifest=json.loads((bundle.parent/"manifest.json").read_bytes())
        need(manifest["componentBinding"]["enabled"] is (state=="enabled") and manifest["files"][GENERATED]==wanted,
             "Generated test mode mismatch")
        target=dest/"composeApp/src/iosMain/kotlin/dev/maduikit/demo/generated"/GENERATED
        target.parent.mkdir(parents=True)
        shutil.copyfile(bundle,target)
        subprocess.run([sys.executable,str(dest/"scripts/verify-generated.py"),str(codegen)],check=True)

def attest(dest,state):
    names=dest/"composeApp/src/iosMain/kotlin/dev/maduikit/demo/generated"
    source=names/GENERATED
    need(source.is_file() and source.resolve()==source,"Missing or linked pinned typed source")
    digest=sha(source.read_bytes())
    bundle=dest/"verified-bundle"/GENERATED
    need(digest==SOURCE_HASH[state] and not bundle.is_symlink() and digest==sha(bundle.read_bytes()),
         "Exact generated code changed after typed build")
    return dict(appBundle=APP_BUNDLE,xctestBundle=TEST_BUNDLE,enabled=(state=="enabled"),
                generatedSha256=digest,codegenPin=CODEGEN_PIN,sourceDemoPin=DEMO_PROBE)

if __name__=="__main__":
    if len(sys.argv)==4 and sys.argv[1]=="--attest":
        print(json.dumps(attest(Path(sys.argv[2]),sys.argv[3]),indent=2))
        sys.exit(0)
    materialize(*(Path(x).resolve(strict=True) for x in sys.argv[1:4]))
