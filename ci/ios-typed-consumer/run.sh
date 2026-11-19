#!/usr/bin/env bash
set -euo pipefail
[[ $(uname -s) == Darwin && $(uname -m) == x86_64 ]] || exit 2
root="$PWD";out="$RUNNER_TEMP/ios-typed-evidence";work="$(mktemp -d "$RUNNER_TEMP/ios-typed.XXXXXX")";sdk="$work/sdk";demo="$work/consumer";stage="$work/maven"
mkdir -p "$out" "$sdk" "$demo"
exec > >(tee "$out/build.log") 2>&1
runlog(){ local name="$1";shift; python3 "$root/ci/ios-typed-consumer/bounded-stage.py" "$name" 900 "$out/$name.log" "$@"; }
test "$(git -C ci-input/sdk rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
test "$(git -C ci-input/codegen rev-parse HEAD)" = 7276d8f3843a91ec5394e527fcbd1a63ad99a712
codegen="$root/ci-input/codegen"
printf 'demoProbe=%s\nsdk=%s\ncodegen=%s\n' "$(git rev-parse HEAD)" "$(git -C ci-input/sdk rev-parse HEAD)" "$(git -C ci-input/codegen rev-parse HEAD)" > "$out/pins.txt"
git -C ci-input/sdk archive HEAD | tar -x -C "$sdk"
python3 - "$sdk" <<'PYS'
from pathlib import Path
import sys,hashlib
root=Path(sys.argv[1]);before={str(p):p.read_bytes() for p in root.rglob('*.kt')}
for name in ['maduikit-components','maduikit-theme']:
 p=root/name/'build.gradle.kts';s=p.read_text();assert s.count('    iosArm64()\n')==1;p.write_text(s.replace('    iosArm64()\n','    iosArm64()\n    iosX64()\n'))
assert all(Path(p).read_bytes()==b for p,b in before.items())
print('SDK Kotlin unchanged; temporary iosX64 build adapter only.')
PYS
cp -R ci/ios-typed-consumer/consumer/. "$demo/"
cp "$sdk/gradlew" "$demo/";cp -R "$sdk/gradle" "$demo/"
# Select only an installed Xcode/simulator pair; never download a runtime or use a paid runner.
developer=''; sim=''
for version in 26.0.1 26.0 26.1.1 26.1 26.2 26.3 16.4; do
  candidate="/Applications/Xcode_$version.app/Contents/Developer"
  [[ -d "$candidate" ]] || continue
  sdk_ver="$(DEVELOPER_DIR="$candidate" xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null)" || continue
  runtime="com.apple.CoreSimulator.SimRuntime.iOS-${sdk_ver//./-}"
  sim="$(DEVELOPER_DIR="$candidate" xcrun simctl list devices available -j | python3 -c '
import json,sys
items=json.load(sys.stdin)["devices"].get(sys.argv[1],[])
items=sorted((d for d in items if d.get("isAvailable") and d["name"].startswith("iPhone ")), key=lambda d:d["name"])
if items: print(items[0]["udid"])
' "$runtime")" || continue
  if [[ "$sim" =~ ^[0-9a-fA-F-]{36}$ ]]; then developer="$candidate"; break; fi
done
[[ -n "$developer" ]] || { echo 'No matching installed Xcode/iPhone runtime'; exit 2; }
export DEVELOPER_DIR="$developer"
xcodebuild -version > "$out/xcode.txt"
printf 'architecture=%s\nsdk=%s\nruntime=%s\nsimulator=%s\n' "$(uname -m)" "$sdk_ver" "$runtime" "$sim" >> "$out/xcode.txt"
java -version 2> "$out/java.txt"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK needed for Gradle project configuration}}"
if [[ ! -f "$ANDROID_HOME/platforms/android-36/android.jar" ]]; then
  runlog android-sdk sdkmanager --sdk_root="$ANDROID_HOME" 'platforms;android-36'
fi

(cd "$sdk" && runlog stage bash gradlew --no-daemon -PmaduikitStagingDir="$stage" :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository :maduikit-theme:publishIosX64PublicationToMadUIKitLocalRepository :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository :maduikit-components:publishIosX64PublicationToMadUIKitLocalRepository)
(cd "$codegen" && runlog codegen bash gradlew --no-daemon --console=plain check installDist)
export ORG_GRADLE_PROJECT_madStage="$stage"
export ORG_GRADLE_PROJECT_madCodegen="$codegen"
(cd "$demo" && runlog resolution bash gradlew --no-daemon :composeApp:verifyAdoption)
cp "$demo/composeApp/build/reports/sdk-adoption.txt" "$out/"
cp -R "$stage" "$out/versioned-maven"
# Two configurations of the same single-tab screen. Boolean is snapshot-authored,
# so do not pretend runtime flags can disable an enabled generated call.
for state in enabled disabled; do
 stateOut="$out/$state"
 python3 "$root/ci/ios-typed-consumer/prepare-bundle.py" "$codegen" "$demo" "$stateOut" "$state"
 python3 - "$root" "$demo" "$state" <<'PYTEST'
from pathlib import Path
import sys
root,demo=map(Path,sys.argv[1:3]);state=sys.argv[3]
p=root/'ci/ios-typed-consumer/consumer/iosApp/BookFilterUITests.swift'
s=p.read_text();assert s.count('EXPECT_ENABLED')==1
(demo/'iosApp/BookFilterUITests.swift').write_text(s.replace('EXPECT_ENABLED',str(state=='enabled').lower()))
PYTEST
 # Verify task is a Kotlin compilation prerequisite and repeats here for explicit evidence.
 (cd "$demo" && runlog "verify-$state" bash gradlew --no-daemon :composeApp:verifyGeneratedBinding :composeApp:verifyAdoption)
 (cd "$demo" && runlog "framework-$state" bash gradlew --no-daemon --console=plain :composeApp:linkDebugFrameworkIosX64)
python3 - "$demo" "$sdk_ver" <<'PYFRAME'
from pathlib import Path
import hashlib,json,shutil,sys
root=Path(sys.argv[1]);sdk='iphonesimulator'+sys.argv[2]
source=root/'composeApp/build/bin/iosX64/debugFramework/MadUIKitDemoShared.framework'
assert (source/'MadUIKitDemoShared').is_file() and (source/'Headers/MadUIKitDemoShared.h').is_file()
target=root/'composeApp/build/xcode-frameworks/Debug'/sdk/source.name
if target.exists(): shutil.rmtree(target)
shutil.copytree(source,target)
files={str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
(root/'prebuilt-framework.json').write_text(json.dumps({'sdkName':sdk,'files':files},indent=2))
PYFRAME
cp "$demo/prebuilt-framework.json" "$stateOut/"
xcrun lipo -archs "$demo/composeApp/build/bin/iosX64/debugFramework/MadUIKitDemoShared.framework/MadUIKitDemoShared" | tee "$stateOut/framework-architecture.txt"
grep -Fx x86_64 "$stateOut/framework-architecture.txt"
runlog "boot-$state" xcrun simctl bootstatus "$sim" -b
args=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$work/derived-$state" -parallel-testing-enabled NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO)
runlog "xcode-$state" xcodebuild "${args[@]}" build-for-testing
runlog "xcui-$state" xcodebuild "${args[@]}" -resultBundlePath "$work/$state.xcresult" -only-testing:MadUIKitDemoUITests/BookFilterUITests/testGeneratedBinding test-without-building
xcrun xcresulttool get test-results summary --path "$work/$state.xcresult" > "$stateOut/test-summary.json"
mkdir "$work/attachments-$state"
xcrun xcresulttool export attachments --path "$work/$state.xcresult" --output-path "$work/attachments-$state"
python3 - "$work/attachments-$state" "$stateOut" <<'PYX'
from pathlib import Path
import json,sys,shutil
r,o=map(Path,sys.argv[1:])
def walk(x):
 if isinstance(x,dict):
  if 'exportedFileName' in x:yield x
  else:
   for v in x.values():yield from walk(v)
 elif isinstance(x,list):
  for v in x:yield from walk(v)
a=[v for v in walk(json.loads((r/'manifest.json').read_text())) if v.get('suggestedHumanReadableName','').startswith('Typed-')]
assert len(a)==2
for item in a:
 n=item['exportedFileName'];assert Path(n).name==n and n.endswith('.png')
 name=item['suggestedHumanReadableName']
 phase='before' if name.startswith('Typed-before') else 'after'
 shutil.copyfile(r/n,o/(phase+'.png'))
assert (o/'before.png').is_file() and (o/'after.png').is_file()

PYX
(cd "$stateOut" && shasum -a256 before.png after.png > screenshots.sha256)
done
echo 'PASS: exact verified generated component/font bundles in independent Maven consumer; enabled physical tap exactly once, disabled no-op. Intel simulator only.' > "$out/result.txt"
