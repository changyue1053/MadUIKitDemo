#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
root="$(pwd -P)"
base=adb2a218a5e8313bbd2c384eeb6a7c7c8fb1dd02
pin=19c8c1b1fbe75b7d6a6118fdab42048948de091b
ci="$root/ci/ios-arm-sim-adoption"
out="${RUNNER_TEMP:?}/ios-arm-sim-evidence"
work="$(mktemp -d "$RUNNER_TEMP/ios-arm-sim.XXXXXX")"
work="$(cd "$work" && pwd -P)"
sdk="$work/sdk"; demo="$work/consumer"; stage="$work/maven"
mkdir -p "$out" "$sdk" "$demo"
runlog(){ local name="$1" bound="$2"; shift 2; python3 "$ci/bounded-stage.py" "$name" "$bound" "$out/$name.log" "$@"; }
test "$(git rev-parse HEAD^)" = "$base"
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
# Exact Xcode from successful prior ARM64 simulator link. Do not enumerate, boot or install simulator devices.
export DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
sdk_ver="$(xcrun --sdk iphonesimulator --show-sdk-version)"
test "$sdk_ver" = 26.0
xcodebuild -version > "$out/xcode.txt"
printf 'arch=arm64\nsdk=%s\ndestination=generic/platform=iOS Simulator\n' "$sdk_ver" >> "$out/xcode.txt"
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
export ORG_GRADLE_PROJECT_madStage="$stage"
(cd "$demo" && runlog resolution 300 bash gradlew --no-daemon --console=plain :composeApp:verifyAdoption)
cp "$demo/composeApp/build/reports/sdk-adoption.txt" "$out/"
(cd "$demo" && runlog framework 900 bash gradlew --no-daemon --console=plain :composeApp:linkDebugFrameworkIosSimulatorArm64)
framework="$demo/composeApp/build/bin/iosSimulatorArm64/debugFramework/MadUIKitDemoShared.framework"
xcrun lipo -archs "$framework/MadUIKitDemoShared" > "$out/framework-architecture.txt"
grep -Fx arm64 "$out/framework-architecture.txt"
xcrun otool -l "$framework/MadUIKitDemoShared" > "$out/framework-load-commands.txt"
python3 "$ci/receipt.py" "$sdk" "$root/ci-input/sdk" "$demo" "$framework" "$out" "$sdk_ver" "$(git rev-parse HEAD)"
printf '{"runtime":"not-run","reason":"compile-only readiness; no simulator boot in this workflow"}\n' > "$out/runtime.json"
derived="$work/derived"
args=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug
 -destination "generic/platform=iOS Simulator" -derivedDataPath "$derived" -parallel-testing-enabled NO
 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO)
runlog host-build 480 xcodebuild "${args[@]}" build-for-testing
python3 "$ci/ready-products.py" "$derived/Build/Products" "$out/built-test-products.json" "$(git rev-parse HEAD)"
