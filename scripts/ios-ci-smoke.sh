#!/usr/bin/env bash
# A bounded public synthetic smoke test, not an iOS parity or release gate.
set -euo pipefail
die() { printf '%s\n' "$*" >&2; exit 2; }
[[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || die "Apple Silicon macOS required"
: "${RUNNER_TEMP:?GitHub hosted runner temporary workspace required}"
root="$(pwd -P)"
out="$RUNNER_TEMP/maduikit-ios-evidence"
mkdir -p "$out"
work="$(mktemp -d "$RUNNER_TEMP/maduikit-ios-work.XXXXXX")"
stage="$work/maven-stage"
demo="$work/demo"
sdk="$root/ci-input/sdk"
codegen="$root/ci-input/codegen"
demo_commit=daf3b9c2dd84501604cb07287d5bc48bafa25745
sdk_commit=b2aef1c1b4f1e09f014c70a3ee19ea7a0d494e42
codegen_commit=b174b847a6e4096924bb1026d1b94a8d9a0c49a8

# Full logs stay ephemeral. Copy only bounded endings to the public artifact.
collect_logs() {
    for log in "$work"/*.log; do
        [[ -f "$log" ]] || continue
        tail -c 250000 "$log" >"$out/$(basename "$log")"
    done
}
trap collect_logs EXIT
runlog() {
    local name="$1"; shift
    if ! "$@" >"$work/$name.log" 2>&1; then
        tail -n 100 "$work/$name.log" >&2
        return 1
    fi
    tail -n 12 "$work/$name.log"
}
[[ "$(git -C "$sdk" rev-parse HEAD)" == "$sdk_commit" ]] || die "Unexpected SDK pin"
[[ "$(git -C "$codegen" rev-parse HEAD)" == "$codegen_commit" ]] || die "Unexpected Codegen pin"
git merge-base --is-ancestor "$demo_commit" HEAD || die "Unexpected Demo parent"
git diff --exit-code "$demo_commit" HEAD -- . \
    ':(exclude).github/workflows/ios-synthetic-smoke.yml' ':(exclude)scripts/ios-ci-smoke.sh' \
    ':(exclude)scripts/verify-ios-ci-stage.py' || die "Unexpected changes to public Demo"
printf 'demo=%s\nsdk=%s\ncodegen=%s\n' "$demo_commit" "$sdk_commit" "$codegen_commit" >"$out/public-commits.txt"
mkdir "$demo"
# Use exact immutable Demo source, without git metadata, SDK checkout, or workflow files.
git archive "$demo_commit" | tar -x -C "$demo"
generated='composeApp/src/commonMain/kotlin/dev/maduikit/demo/generated/FigmaProfileScreen.generated.kt'
cmp "$demo/$generated" "$codegen/sample-gradient-output/FigmaProfileScreen.generated.kt"
shasum -a 256 "$demo/$generated" | cut -d ' ' -f 1 > "$out/public-fixture.sha256"
python3 "$demo/scripts/check-structure.py"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export PATH="$JAVA_HOME/bin:$PATH"
java -version >"$out/java-version.txt" 2>&1
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?No installed Android SDK}}"
if [[ ! -f "$ANDROID_HOME/platforms/android-36/android.jar" ]]; then
    runlog android-sdk sdkmanager --sdk_root="$ANDROID_HOME" 'platforms;android-36'
fi
[[ -f "$ANDROID_HOME/platforms/android-36/android.jar" ]] || die "Android API 36 not installed"

# Kotlin 2.2.21 is validated with Xcode 26.0; prefer nearest matching available
# SDK/runtime pair. Never download a simulator runtime or change system Xcode.
developer=''
sim=''
for version in 26.0.1 26.0 26.1.1 26.1 26.2 26.3 26.4.1 26.4 26.5 26.6; do
    candidate="/Applications/Xcode_$version.app/Contents/Developer"
    [[ -d "$candidate" ]] || continue
    sdk_ver="$(DEVELOPER_DIR="$candidate" xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null)" || continue
    [[ "$sdk_ver" =~ ^26[.]([0-9]+) ]] || continue
    runtime="com.apple.CoreSimulator.SimRuntime.iOS-26-${BASH_REMATCH[1]}"
    sim="$(DEVELOPER_DIR="$candidate" xcrun simctl list devices available -j | python3 -c '
import json,sys
devices = json.load(sys.stdin)["devices"].get(sys.argv[1], [])
available = sorted((d for d in devices if d.get("isAvailable", False) and d["name"].startswith("iPhone ")),
                   key=lambda d: (d.get("state") != "Booted", d["name"], d["udid"]))
if available:
    print(available[0]["udid"])' "$runtime")" || continue
    if [[ "$sim" =~ ^[0-9a-fA-F-]{36}$ ]]; then
        developer="$candidate"
        break
    fi
done
[[ -n "$developer" ]] || die "No matching preinstalled Xcode 26.x and iOS 26.x iPhone Simulator; no runtime download attempted"
export DEVELOPER_DIR="$developer"
xcodebuild -version >"$out/xcode-version.txt"
printf 'sdk=%s\nruntime=%s\nsimulator=%s\n' "$sdk_ver" "$runtime" "$sim" >>"$out/xcode-version.txt"

publish() (
    cd "$sdk" || exit 1
    [[ ! -e "$stage" ]] || die "Maven staging must start empty"
    ./gradlew --no-daemon -PmaduikitStagingDir="$stage" \
      :maduikit-theme:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository \
      :maduikit-components:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository \
      :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
      :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository
)
runlog sdk-stage publish
python3 "$root/scripts/verify-ios-ci-stage.py" "$stage" | tee "$out/staged-ios-klibs.json"

# The Demo is a fresh independent archive, with no composite/project substitution.
export ORG_GRADLE_PROJECT_maduikitStagingDir="$stage"
unset OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED
runlog simulator-boot xcrun simctl bootstatus "$sim" -b
runlog xcode-build xcodebuild -project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo \
  -configuration Debug -destination "platform=iOS Simulator,id=$sim" \
  -derivedDataPath "$work/derived-data" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build

app="$work/derived-data/Build/Products/Debug-iphonesimulator/MadUIKitDemo.app"
bundle='dev.maduikit.demo'
[[ -f "$app/Info.plist" ]] || die "Simulator app not found"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")" == "$bundle" ]] || die "Unexpected simulator bundle"
runlog simulator-install xcrun simctl install "$sim" "$app"
runlog simulator-launch xcrun simctl launch --terminate-running-process "$sim" "$bundle"
pid="$(awk '/^dev[.]maduikit[.]demo: [0-9]+$/ { print $2 }' "$work/simulator-launch.log")"
[[ "$pid" =~ ^[0-9]+$ ]] || die "No launched app PID"
sleep 4
kill -0 "$pid" || die "Simulator app exited before capture"
xcrun simctl io "$sim" screenshot "$out/MadUIKitDemo-iOS-Simulator.png"
kill -0 "$pid" || die "Simulator app exited during capture"
sips -g pixelWidth -g pixelHeight "$out/MadUIKitDemo-iOS-Simulator.png" | tee "$out/screenshot-dimensions.txt"
(cd "$out" && shasum -a 256 MadUIKitDemo-iOS-Simulator.png > screenshot.sha256)
