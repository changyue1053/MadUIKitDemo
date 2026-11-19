#!/usr/bin/env bash
set -euo pipefail
root="$PWD"; out="$RUNNER_TEMP/ios-arm64-adoption-evidence"; work="$(mktemp -d "$RUNNER_TEMP/arm-adoption.XXXXXX")"; sdk="$work/sdk"; demo="$work/consumer"; stage="$work/maven"
mkdir -p "$out" "$sdk" "$demo"
exec > >(tee "$out/build.log") 2>&1
runlog(){ local name="$1"; shift; python3 "$root/ci/ios-arm64-adoption/bounded-stage.py" "$name" 900 "$out/$name.log" "$@"; }
test "$(uname -m)" = x86_64
test "$(git -C ci-input/sdk rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
git -C ci-input/sdk archive HEAD | tar -x -C "$sdk"
# SDK source AND build definitions remain byte-identical to pinned upstream.
cp -R ci/ios-arm64-adoption/consumer/. "$demo/"
cp "$sdk/gradlew" "$demo/"; cp -R "$sdk/gradle" "$demo/"
export DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
xcodebuild -version > "$out/xcode.txt"
xcrun --sdk iphoneos --show-sdk-version >> "$out/xcode.txt"
uname -m >> "$out/xcode.txt"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required for project configuration}}"
if [[ ! -f "$ANDROID_HOME/platforms/android-36/android.jar" ]]; then
 runlog android-sdk sdkmanager --sdk_root="$ANDROID_HOME" 'platforms;android-36'
fi
(cd "$sdk" && runlog stage bash gradlew --no-daemon --console=plain -PmaduikitStagingDir="$stage" :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository :maduikit-theme:publishIosArm64PublicationToMadUIKitLocalRepository :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository :maduikit-components:publishIosArm64PublicationToMadUIKitLocalRepository)
export ORG_GRADLE_PROJECT_madStage="$stage"
(cd "$demo" && runlog resolution bash gradlew --no-daemon --console=plain :composeApp:verifyAdoption)
cp "$demo/composeApp/build/reports/sdk-adoption.txt" "$out/"
cp -R "$stage" "$out/versioned-maven"
(cd "$demo" && runlog framework bash gradlew --no-daemon --console=plain :composeApp:linkDebugFrameworkIosArm64)
framework="$demo/composeApp/build/bin/iosArm64/debugFramework/MadUIKitDemoShared.framework"
xcrun lipo -archs "$framework/MadUIKitDemoShared" | tee "$out/framework-architecture.txt"
grep -Fx arm64 "$out/framework-architecture.txt"
xcrun otool -l "$framework/MadUIKitDemoShared" > "$out/framework-load-commands.txt"
# LC_BUILD_VERSION platform 2 = device iOS; 7 would be iOS simulator.
python3 - "$sdk" "$root/ci-input/sdk" "$framework" "$out" <<'PY'
from pathlib import Path
import hashlib,json,re,sys
sdk,original,framework,out=map(Path,sys.argv[1:])
files=[p for p in original.rglob('*') if p.is_file() and '.git' not in p.parts]
for p in files:
 q=sdk/p.relative_to(original)
 assert q.is_file() and q.read_bytes()==p.read_bytes(),str(p)
commands=(out/'framework-load-commands.txt').read_text()
platforms=re.findall(r'^\s*platform\s+(\S+)',commands,re.M)
assert platforms and set(platforms)<= {'2','IOS'},platforms
assert (framework/'Headers/MadUIKitDemoShared.h').is_file()
receipt={'sdkCommit':'19c8c1b1fbe75b7d6a6118fdab42048948de091b','unchangedSdkTrackedFiles':len(files),'host':'x86_64','target':'ios_arm64','platforms':sorted(set(platforms)),'frameworkFiles':{str(p.relative_to(framework)):hashlib.sha256(p.read_bytes()).hexdigest() for p in framework.rglob('*') if p.is_file()},'runtimeVerified':False,'signed':False}
(out/'compile-receipt.json').write_text(json.dumps(receipt,indent=2))
PY
cp -R "$framework" "$out/"
echo 'PASS: unmodified upstream SDK via staged Maven, independent ARM64 device framework compile/link only. No app packaging, signing, device execution or screenshot.' > "$out/result.txt"
