#!/usr/bin/env bash
set -euo pipefail
[[ $(uname -s) == Darwin && $(uname -m) == x86_64 ]] || { echo 'Standard Intel macOS required'; exit 2; }
root="$(pwd -P)"
out="${RUNNER_TEMP:?}/mad-ios-verified-evidence"
work="$(mktemp -d "$RUNNER_TEMP/mad-ios-verified.XXXXXX")"
mkdir -p "$out" "$work/sdk" "$work/demo"
sdk="$work/sdk"; demo="$work/demo"; stage="$work/maven-stage"
codegen="$root/ci-input/codegen"
test "$(git -C "$root/ci-input/sdk" rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
test "$(git -C "$codegen" rev-parse HEAD)" = 9ac33f74fcbe51067f6b7de544043f97591e7ec1
git merge-base --is-ancestor 8f386c28d1b5709f3ce57adae2912993c1f8222f HEAD
git diff --exit-code 8f386c28d1b5709f3ce57adae2912993c1f8222f HEAD -- . ':!ci/ios-verified-consumer' ':!.github/workflows/ios-verified-consumer.yml' ':!docs/IOS-VERIFIED-CONSUMER.md'
git -C "$root/ci-input/sdk" archive HEAD | tar -x -C "$sdk"
git archive 8f386c28d1b5709f3ce57adae2912993c1f8222f | tar -x -C "$demo"
printf 'probe=%s\ndemo=%s\nsdk=%s\ncodegen=%s\n' "$(git rev-parse HEAD)" 8f386c28d1b5709f3ce57adae2912993c1f8222f 19c8c1b1fbe75b7d6a6118fdab42048948de091b 9ac33f74fcbe51067f6b7de544043f97591e7ec1 > "$out/commits.txt"
collect() {
  for f in "$work"/*.log; do
    [[ -f "$f" ]] || continue
    grep -E '^(> Task |BUILD |Verified |Demo consumer|Demo verified|Isolated |\*\* BUILD|error:|warning:|[^[:space:]]+:[0-9]+:[0-9]+: (error|warning):|.*[Ee]xception.*|.*[Ff]ailed.*|.*Could not.*)' "$f" | tail -c 60000 > "$out/$(basename "$f")" || true
  done
}
trap collect EXIT
runlog() {
  local name="$1"; shift
  if ! "$@" > "$work/$name.log" 2>&1; then tail -n 90 "$work/$name.log"; return 1; fi
  echo "$name passed"
}
python3 "$root/ci/ios-verified-consumer/prepare-intel.py" "$sdk" "$demo" | tee "$out/source-adapter.txt"
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
(cd "$codegen" && runlog codegen bash gradlew --no-daemon check installDist)
export ORG_GRADLE_PROJECT_maduikitStagingDir="$stage"
export ORG_GRADLE_PROJECT_maduikitCodegenDir="$codegen"
(cd "$sdk" && runlog sdk-stage bash gradlew --no-daemon \
  :maduikit-theme:publishIosX64PublicationToMadUIKitLocalRepository \
  :maduikit-components:publishIosX64PublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository)
(cd "$demo" && runlog bundle-and-sdk bash gradlew --no-daemon :composeApp:verifyGeneratedSource \
  :composeApp:consumerSmokeTest :composeApp:verifyStagedIosX64Sdk)
runlog simulator-boot xcrun simctl bootstatus "$sim" -b
unset OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED
runlog xcode-build xcodebuild -project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo \
  -configuration Debug -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$work/derived" \
  ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
app="$work/derived/Build/Products/Debug-iphonesimulator/MadUIKitDemo.app"
python3 - "$app/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: p=plistlib.load(f)
assert p['CFBundleIdentifier']=='dev.maduikit.demo'
assert p['CADisableMinimumFrameDurationOnPhone'] is True
PY
xcrun lipo -archs "$app/MadUIKitDemo" | tee "$out/app-architecture.txt"
grep -Fx x86_64 "$out/app-architecture.txt"
xcrun simctl install "$sim" "$app"
xcrun simctl launch --terminate-running-process "$sim" dev.maduikit.demo | tee "$out/launch.txt"
grep -E '^dev.maduikit.demo: [0-9]+' "$out/launch.txt"
runlog inspector xcrun swiftc "$root/ci/ios-verified-consumer/inspect.swift" -o "$work/inspect-png"
visible=false
for i in $(seq 1 15); do
  xcrun simctl io "$sim" screenshot "$out/iOS-Verified-Consumer-Intel.png"
  if "$work/inspect-png" "$out/iOS-Verified-Consumer-Intel.png" > "$out/gradient-proof.txt"; then visible=true; break; fi
  sleep 2
done
test "$visible" = true
xcrun simctl spawn "$sim" launchctl list | grep -F dev.maduikit.demo > "$out/running-app.txt"
(cd "$out" && shasum -a 256 iOS-Verified-Consumer-Intel.png > screenshot.sha256)
printf 'PASS: Intel simulator application built from verified synthetic bundle, launched and captured with gradient markers. Not ARM64, physical device, interaction or Figma-parity validation.\n' | tee "$out/result.txt"
