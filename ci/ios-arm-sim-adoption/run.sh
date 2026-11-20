#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
root="$(pwd -P)"
base=d9e0725282bca7ca01ac3a9d060a8ab000117cf1
pin=19c8c1b1fbe75b7d6a6118fdab42048948de091b
ci="$root/ci/ios-arm-sim-adoption"
out="${RUNNER_TEMP:?}/ios-arm-sim-evidence"
work="$(mktemp -d "$RUNNER_TEMP/ios-arm-sim.XXXXXX")"
work="$(cd "$work" && pwd -P)"
sdk="$work/sdk"; demo="$work/consumer"; stage="$work/maven"
mkdir -p "$out" "$sdk" "$demo"
runlog(){ local name="$1" bound="$2"; shift 2; python3 "$ci/bounded-stage.py" "$name" "$bound" "$out/$name.log" "$@"; }
git merge-base --is-ancestor "$base" HEAD
git diff --exit-code "$base" HEAD -- . ':!ci/ios-arm-sim-adoption' ':!.github/workflows/ios-arm-sim-adoption.yml'
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
git -C ci-input/sdk archive HEAD | tar -x -C "$sdk"
cp -R "$ci/consumer/." "$demo"
cp "$sdk/gradlew" "$demo/"; cp -R "$sdk/gradle" "$demo/"
python3 - "$demo" <<'PYGUARD'
from pathlib import Path
import re,sys
project=Path(sys.argv[1])
scripts=sorted(project.rglob("*.gradle.kts"))
if len(scripts)!=3:
    raise SystemExit("Unexpected consumer Gradle script inventory")
for script in scripts:
    if script.is_symlink() or not script.is_file():
        raise SystemExit("Linked or invalid consumer script")
    text=script.read_text(encoding="utf-8")
    if re.search(r"includeBuild|flatDir|mavenLocal|implementation\s*\(\s*files|api\s*\(\s*project",text):
        raise SystemExit("Unexpected local SDK substitution")
PYGUARD
developer=''; sim=''; sdk_ver=''
# Use an already installed Xcode / iPhone pairing. An eligible toolchain without a runtime still permits link-only.
for version in 26.0.1 26.0 26.1.1 26.1 26.2 26.3 16.4; do
 candidate="/Applications/Xcode_$version.app/Contents/Developer"
 [[ -d "$candidate" ]] || continue
 v="$(DEVELOPER_DIR="$candidate" xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null)" || continue
 [[ "$v" =~ ^[0-9]+(\.[0-9]+)+$ ]] || continue
 if [[ -z "$developer" ]]; then developer="$candidate"; sdk_ver="$v"; fi
 key="com.apple.CoreSimulator.SimRuntime.iOS-${v//./-}"
 id="$(DEVELOPER_DIR="$candidate" xcrun simctl list devices available -j | python3 "$ci/simulator-id.py" "$key")" || continue
 if [[ "$id" =~ ^[0-9a-fA-F-]{36}$ ]]; then developer="$candidate"; sdk_ver="$v"; sim="$id"; break; fi
done
[[ -n "$developer" ]] || { echo 'No approved installed simulator SDK toolchain'; exit 2; }
export DEVELOPER_DIR="$developer"
xcodebuild -version > "$out/xcode.txt"
printf 'arch=arm64\nsdk=%s\neligibleSimulator=%s\n' "$sdk_ver" "${sim:+yes}" >> "$out/xcode.txt"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required for KMP configuration}}"
if [[ ! -f "$ANDROID_HOME/platforms/android-36/android.jar" ]]; then
 runlog android-sdk 300 "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" 'platforms;android-36'
fi
(cd "$sdk" && runlog stage 900 bash gradlew --no-daemon --console=plain "-PmaduikitStagingDir=$stage" \
  :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository \
  :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-components:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository)
python3 "$ci/verify-filesystem.py" "$stage" --target iossimulatorarm64 > "$out/filesystem.json"
python3 - "$stage" <<'PYSTAGE'
from pathlib import Path
import sys
stage=Path(sys.argv[1])
allowed={f"maduikit-{name}{suffix}" for name in ("theme","components") for suffix in ("","-iossimulatorarm64")}
seen=set()
for entry in stage.rglob("*"):
    if entry.is_symlink() or not (entry.is_file() or entry.is_dir()):
        raise SystemExit("Invalid or linked staged path")
    parts=entry.relative_to(stage).parts
    if parts[:3] != ("com","mad","maduikit")[:len(parts)]:
        raise SystemExit("Non-SDK entry in Maven stage")
    if len(parts)<4:
        if not entry.is_dir(): raise SystemExit("Namespace must be a directory")
    else:
        if parts[3] not in allowed: raise SystemExit("Unexpected SDK publication")
        if len(parts)==4:
            if not entry.is_dir(): raise SystemExit("Publication must be a directory")
            seen.add(parts[3])
if seen!=allowed:
    raise SystemExit("Missing exact stage namespace")
PYSTAGE
cp -R "$stage" "$out/versioned-maven"
export ORG_GRADLE_PROJECT_madStage="$stage"
(cd "$demo" && runlog resolution 300 bash gradlew --no-daemon --console=plain :composeApp:verifyAdoption)
cp "$demo/composeApp/build/reports/sdk-adoption.txt" "$out/"
(cd "$demo" && runlog framework 900 bash gradlew --no-daemon --console=plain :composeApp:linkDebugFrameworkIosSimulatorArm64)
framework="$demo/composeApp/build/bin/iosSimulatorArm64/debugFramework/MadUIKitDemoShared.framework"
xcrun lipo -archs "$framework/MadUIKitDemoShared" > "$out/framework-architecture.txt"
grep -Fx arm64 "$out/framework-architecture.txt"
xcrun otool -l "$framework/MadUIKitDemoShared" > "$out/framework-load-commands.txt"
python3 "$ci/receipt.py" "$sdk" "$root/ci-input/sdk" "$demo" "$framework" "$out" "$sdk_ver" "$(git rev-parse HEAD)"
if [[ -z "$sim" ]]; then
 printf '{"runtime":"not-run","reason":"no eligible installed iPhone simulator"}\n' > "$out/runtime.json"
 exit 0
fi
printf '{"runtime":"attempted-not-yet-verified"}\n' > "$out/runtime.json"
runlog boot 420 xcrun simctl bootstatus "$sim" -b
args=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug
 -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$work/derived" -parallel-testing-enabled NO
 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO)
runlog host-build 480 xcodebuild "${args[@]}" build-for-testing
app="$work/derived/Build/Products/Debug-iphonesimulator/MadUIKitDemo.app/MadUIKitDemo"
xcrun lipo -archs "$app" | grep -Fx arm64
xcrun otool -l "$app" > "$out/app-load-commands.txt"
python3 "$ci/runtime-proof.py" platform "$out/app-load-commands.txt"
runlog test 480 xcodebuild "${args[@]}" -resultBundlePath "$work/result.xcresult" \
 -only-testing:MadUIKitDemoUITests/BookFilterUITests/testIndependentConsumer test-without-building
xcrun xcresulttool get test-results summary --path "$work/result.xcresult" > "$out/test-summary.json"
mkdir "$work/attachments"
xcrun xcresulttool export attachments --path "$work/result.xcresult" --output-path "$work/attachments"
python3 "$ci/runtime-proof.py" passed "$out" "$work/attachments"
