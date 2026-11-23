#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
root="$(pwd -P)"
base=4c10c401bdf59a8c3986b8489203214af711d810
pin=19c8c1b1fbe75b7d6a6118fdab42048948de091b
ci="$root/ci/ios-arm-sim-adoption"
out="${RUNNER_TEMP:?}/sdk-unified-evidence"
work="$(mktemp -d "$RUNNER_TEMP/ios-arm-sim.XXXXXX")"
work="$(cd "$work" && pwd -P)"
sdk="$work/sdk"; demo="$work/books"; stage="$work/maven"
mkdir -p "$out" "$sdk" "$demo"
new="$root/ci/sdk-unified-stage"
diag="$out/diagnostic"
mkdir -p "$diag"
gate=precheck
finish(){ local code=$?; trap - EXIT; python3 "$new/diagnostics.py" "$out" "$gate" "$code" || true; exit "$code"; }
trap finish EXIT
runlog(){ local name="$1" bound="$2"; shift 2; gate="$name"; python3 "$ci/bounded-stage.py" "$name" "$bound" "$out/$name.log" "$@" > "$work/progress.log" 2>&1; }
test "$(git rev-parse HEAD^)" = "$base"
git diff --exit-code "$base" HEAD -- . ':!ci/sdk-unified-stage/run.sh' ':!ci/sdk-unified-stage/diagnostics.py' ':!ci/sdk-unified-stage/android-runtime.sh' ':!ci/sdk-unified-stage/finalize.py' ':!.github/workflows/sdk-unified-stage.yml'
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
git -C ci-input/sdk archive HEAD | tar -x -C "$sdk"
cp -R "$ci/consumer/." "$demo"
cp "$sdk/gradlew" "$demo/"; cp -R "$sdk/gradle" "$demo/"
python3 "$new/consumer.py" "$demo"
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
# New supported public runner family, exact Xcode/guest. No runtime install or alternate retry.
test "${ImageOS:?Missing runner image identity}" = macos26
image="${ImageVersion:?Missing runner image version}"
[[ "$image" =~ ^[0-9]{8}\.[0-9]{4}\.[0-9]+$ && "$image" != 20261118.0550.1 ]]
os="$(sw_vers -productVersion)"
[[ "$os" == 26.* ]]
export DEVELOPER_DIR=/Applications/Xcode_26.4.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
xcodebuild -version > "$out/xcode.txt"
grep -Fx 'Xcode 26.4.1' "$out/xcode.txt"
grep -Fx 'Build version 17E202' "$out/xcode.txt"
sdk_ver="$(xcrun --sdk iphonesimulator --show-sdk-version)"
test "$sdk_ver" = 26.4
printf 'ImageOS=%s\nImageVersion=%s\nmacOS=%s\nsimulatorSDK=%s\n' "$ImageOS" "$image" "$os" "$sdk_ver" >> "$out/xcode.txt"
printf '{"runtime":"not-run","reason":"boot health not yet accepted"}\n' > "$out/runtime.json"
selected="$(xcrun simctl list -j | python3 "$ci/guest-inventory.py" --candidates "$out/guest-candidates.json")"
printf '%s\n' "$selected" > "$out/guest-selected.json"
sim="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["udid"])' "$out/guest-selected.json")"
# Build and prove the same Apple ImageIO profiles before boot. Do not invoke
# the Swift interpreter while holding a live simulator or validating XCUI output.
validator="$work/validate-imageio-frame"
runlog validator-build 180 xcrun --sdk macosx swiftc -O -target arm64-apple-macosx26.0 \
 "$ci/boot-frame.swift" -o "$validator"
runlog validator-prove 35 python3 "$ci/frame-validator.py" prove \
 "$validator" "$ci/boot-frame.swift" "$out/frame-validator.json"
runlog boot 300 xcrun simctl bootstatus "$sim" -b
xcrun simctl list -j | python3 "$ci/guest-inventory.py" "$sim" > "$out/guest-booted.json"
# This PNG is deliberately runner-temp only and cannot be delivered as an application screenshot.
boot_frame="$work/boot-health-only.png"
runlog boot-frame 25 xcrun simctl io "$sim" screenshot "$boot_frame"
python3 "$ci/frame-validator.py" verify "$validator" "$out/frame-validator.json"
runlog frame-check 45 "$validator" "$boot_frame" boot
python3 - "$boot_frame" "$out" <<'PYHEALTH'
from pathlib import Path
import hashlib,json,sys
png,out=map(Path,sys.argv[1:])
lines=(out/"frame-check.log").read_text().splitlines()
proof,=[json.loads(x) for x in lines if x.startswith("{")]
assert proof["decodedPNG"] is True and proof["nonblankCheck"] is True and proof["profile"]=="boot"
proof["scope"]="boot-health only; no Books execution"
proof["runnerTempOnlySha256"]=hashlib.sha256(png.read_bytes()).hexdigest()
(out/"boot-health.json").write_text(json.dumps(proof,indent=2)+"\n")
PYHEALTH
rm -- "$boot_frame"
printf '{"runtime":"not-run","reason":"boot healthy; build/test pending"}\n' > "$out/runtime.json"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required for KMP configuration}}"
if [[ ! -f "$ANDROID_HOME/platforms/android-36/android.jar" ]]; then
 runlog android-sdk 300 "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" 'platforms;android-36'
fi
gate=stage
(cd "$sdk" && runlog stage 900 bash gradlew --no-daemon --console=plain "-PmaduikitStagingDir=$stage" \
  :maduikit-theme:publishAndroidReleasePublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishIosArm64PublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository \
  :maduikit-components:publishAndroidReleasePublicationToMadUIKitLocalRepository \
  :maduikit-components:publishIosArm64PublicationToMadUIKitLocalRepository \
  :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-components:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository)
gate=stage-verify
python3 "$new/verify-stage.py" "$stage" > "$out/stage-before.json"
export ORG_GRADLE_PROJECT_madStage="$stage"
reports="$demo/composeApp/build/reports"
gate=android-resolve
(cd "$demo" && runlog android-resolve 300 bash gradlew --no-daemon --console=plain -Pandroid.useAndroidX=true :composeApp:verifyAndroidAdoption)
cp "$reports/sdk-adoption-android.txt" "$out/android-resolution.txt"
gate=android-build
(cd "$demo" && runlog android-build 600 bash gradlew --no-daemon --console=plain -Pandroid.useAndroidX=true :composeApp:assembleDebug)
gate=ios-resolve
(cd "$demo" && runlog resolution 300 bash gradlew --no-daemon --console=plain -Pandroid.useAndroidX=true :composeApp:verifyAdoption)
cp "$reports/sdk-adoption.txt" "$out/ios-resolution.txt"
gate=android-apk-output
apk="$demo/composeApp/build/outputs/apk/debug/composeApp-debug.apk"
test -s "$apk"
gate=ios-framework
(cd "$demo" && runlog framework 900 bash gradlew --no-daemon --console=plain -Pandroid.useAndroidX=true :composeApp:linkDebugFrameworkIosSimulatorArm64)
framework="$demo/composeApp/build/bin/iosSimulatorArm64/debugFramework/MadUIKitDemoShared.framework"
xcrun lipo -archs "$framework/MadUIKitDemoShared" > "$out/framework-architecture.txt"
grep -Fx arm64 "$out/framework-architecture.txt"
xcrun otool -l "$framework/MadUIKitDemoShared" > "$out/framework-load-commands.txt"
python3 "$ci/receipt.py" "$sdk" "$root/ci-input/sdk" "$demo" "$framework" "$out" "$sdk_ver" "$(git rev-parse HEAD)"
derived="$work/derived"
args=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug
 -destination "generic/platform=iOS Simulator" -derivedDataPath "$derived" -parallel-testing-enabled NO
 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO)
gate=host-build
runlog host-build 480 xcodebuild "${args[@]}" build-for-testing
python3 "$ci/ready-products.py" "$derived/Build/Products" "$out/built-test-products.json" "$(git rev-parse HEAD)"
# Use the actual validated xctestrun; no rebuilding at runtime.
xcrun simctl list -j | python3 "$ci/guest-inventory.py" "$sim" > "$out/guest-before-test.json"
cmp "$out/guest-booted.json" "$out/guest-before-test.json"
test_run="$(python3 - "$derived/Build/Products" "$out/built-test-products.json" <<'PYTEST'
from pathlib import Path
import hashlib,json,sys
products,receipt=map(Path,sys.argv[1:])
d=json.loads(receipt.read_text())
entry=d["xctestrun"]
p=products/entry["path"]
assert p.parent==products and p.resolve()==p and hashlib.sha256(p.read_bytes()).hexdigest()==entry["sha256"]
print(str(p))
PYTEST
)"
printf '{"runtime":"attempted-not-verified","reason":"one XCTest launch requested"}\n' > "$out/runtime.json"
gate=ios-test
runlog test 420 xcodebuild -xctestrun "$test_run" -destination "platform=iOS Simulator,id=$sim" \
 -parallel-testing-enabled NO -resultBundlePath "$work/result.xcresult" \
 -only-testing:MadUIKitDemoUITests/BookFilterUITests/testIndependentConsumer test-without-building
xcrun xcresulttool get test-results summary --path "$work/result.xcresult" > "$out/test-summary.json"
mkdir "$work/attachments"
xcrun xcresulttool export attachments --path "$work/result.xcresult" --output-path "$work/attachments"
python3 "$ci/frame-validator.py" verify "$validator" "$out/frame-validator.json"
gate=ios-runtime-proof
python3 "$ci/runtime-proof.py" "$out" "$work/attachments" "$validator"

gate=stage-recheck
python3 "$new/verify-stage.py" "$stage" > "$out/stage-after.json"
cmp "$out/stage-before.json" "$out/stage-after.json"
# Copy success-only stage and one Android compile artifact (not Android runtime).
delivery="$out/deliverable"
mkdir "$delivery"
cp -R "$stage" "$delivery/versioned-maven"
cp "$apk" "$delivery/public-unified-books-android.apk"
cp "$out/stage-before.json" "$out/android-resolution.txt" "$out/ios-resolution.txt" "$out/runtime.json" "$out/test-summary.json" "$out/xcode.txt" "$delivery/"
cp -R "$out/accepted-runtime" "$delivery/"
(cd "$delivery" && shasum -a 256 public-unified-books-android.apk > android-apk.sha256)
printf 'SDK pin %s\nDemo base %s\nWorkflow commit %s\nRun %s attempt %s\nIntermediate only: Android compiled; Apple Silicon simulator Books launch and labels; iOS device KLIB staged, no device app link or runtime.\n' "$pin" "$base" "$(git rev-parse HEAD)" "$GITHUB_RUN_ID" "$GITHUB_RUN_ATTEMPT" > "$delivery/PROVENANCE.txt"

gate=candidate
python3 "$new/finalize.py" produce "$delivery"
