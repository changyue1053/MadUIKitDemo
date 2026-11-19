#!/usr/bin/env bash
set -euo pipefail
root="$PWD";out="$RUNNER_TEMP/ios-adoption-evidence";work="$(mktemp -d "$RUNNER_TEMP/ios-adoption.XXXXXX")";sdk="$work/sdk";demo="$work/consumer";stage="$work/maven"
mkdir -p "$out" "$sdk" "$demo"
exec > >(tee "$out/build.log") 2>&1
runlog(){ local name="$1";shift; python3 "$root/ci/ios-sdk-adoption/bounded-stage.py" "$name" 900 "$out/$name.log" "$@"; }
test "$(git -C ci-input/sdk rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
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
cp -R ci/ios-sdk-adoption/consumer/. "$demo/"
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
export ORG_GRADLE_PROJECT_madStage="$stage"
(cd "$demo" && runlog resolution bash gradlew --no-daemon :composeApp:verifyAdoption)
cp "$demo/composeApp/build/reports/sdk-adoption.txt" "$out/"
cp -R "$stage" "$out/versioned-maven"
# Compile/link outside Xcode: separate Gradle compiler evidence from host packaging.
(cd "$demo" && runlog framework bash gradlew --no-daemon --console=plain :composeApp:linkDebugFrameworkIosX64)
python3 - "$demo" "$sdk_ver" <<'PYFRAME'
from pathlib import Path
import hashlib,json,shutil,sys
root=Path(sys.argv[1]);sdk='iphonesimulator'+sys.argv[2]
source=root/'composeApp/build/bin/iosX64/debugFramework/MadUIKitDemoShared.framework'
assert (source/'MadUIKitDemoShared').is_file() and (source/'Headers/MadUIKitDemoShared.h').is_file()
target=root/'composeApp/build/xcode-frameworks/Debug'/sdk/source.name
shutil.copytree(source,target)
files={str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
(root/'prebuilt-framework.json').write_text(json.dumps({'sdkName':sdk,'files':files},indent=2))
PYFRAME
cp "$demo/prebuilt-framework.json" "$out/"
xcrun lipo -archs "$demo/composeApp/build/bin/iosX64/debugFramework/MadUIKitDemoShared.framework/MadUIKitDemoShared" | tee "$out/framework-architecture.txt"
grep -Fx x86_64 "$out/framework-architecture.txt"
runlog boot xcrun simctl bootstatus "$sim" -b
args=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$work/derived" -parallel-testing-enabled NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO)
runlog xcode xcodebuild "${args[@]}" build-for-testing
runlog xcui xcodebuild "${args[@]}" -resultBundlePath "$work/result.xcresult" -only-testing:MadUIKitDemoUITests/BookFilterUITests/testIndependentConsumer test-without-building
xcrun xcresulttool get test-results summary --path "$work/result.xcresult" > "$out/test-summary.json"
mkdir "$work/attachments"
xcrun xcresulttool export attachments --path "$work/result.xcresult" --output-path "$work/attachments"
python3 - "$work/attachments" "$out" <<'PYX'
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
a=[v for v in walk(json.loads((r/'manifest.json').read_text())) if v.get('suggestedHumanReadableName','').startswith('Independent-iOS-Books')]
assert len(a)==1
n=a[0]['exportedFileName'];assert Path(n).name==n and n.endswith('.png')
shutil.copyfile(r/n,o/'Independent-iOS-Books.png')
PYX
(cd "$out" && shasum -a256 Independent-iOS-Books.png > screenshot.sha256)
echo 'PASS: independent versioned Maven SDK consumer compiled and actual native labels observed. Intel simulator only.' > "$out/result.txt"
