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
demo_commit=3e649b0391ea07230c5335e05b744c5208016670
sdk_commit=19c8c1b1fbe75b7d6a6118fdab42048948de091b
codegen_commit=dd05c6c863f0c9de2e62017deadb378dd42f5603

# Full logs stay ephemeral. Copy only bounded endings to the public artifact.
collect_logs() {
    for log in "$work"/*.log; do
        [[ -f "$log" ]] || continue
        case "$(basename "$log")" in
          xcode-build.log|sdk-stage.log|simulator-boot.log|xcuitest.log|android-receipt.log)
            { grep -E '^(> Task :[^ ]+|BUILD (SUCCESSFUL|FAILED)|\*\* (BUILD|TEST) (SUCCEEDED|FAILED) \*\*|Error Domain=|Test Case .*BookFilterUITests|Executed [0-9]+ tests?,|[^[:space:]]+:[0-9]+:[0-9]+: (error|warning):|error:|warning:|ld: warning:)' "$log" || true; } |
                tail -c 48000 >"$out/$(basename "$log")" ;;
          *) tail -c 16000 "$log" >"$out/$(basename "$log")" ;;
        esac
    done
}
trap collect_logs EXIT
runlog() {
    local name="$1"; shift
    if ! "$@" >"$work/$name.log" 2>&1; then
        printf "%s failed. See bounded evidence.\n" "$name" >&2
        return 1
    fi
    printf "%s passed.\n" "$name"
}
[[ "$(git -C "$sdk" rev-parse HEAD)" == "$sdk_commit" ]] || die "Unexpected SDK pin"
[[ "$(git -C "$codegen" rev-parse HEAD)" == "$codegen_commit" ]] || die "Unexpected Codegen pin"
git merge-base --is-ancestor "$demo_commit" HEAD || die "Unexpected Demo parent"
overlay=(
    iosApp/BookFilterUITests.swift
    iosApp/MadUIKitDemo.xcodeproj/project.pbxproj
    iosApp/MadUIKitDemo.xcodeproj/xcshareddata/xcschemes/MadUIKitDemo.xcscheme
    composeApp/src/commonMain/kotlin/dev/maduikit/demo/DemoScreen.kt
)
allow=()
for path in "${overlay[@]}" scripts/ios-ci-smoke.sh scripts/export-ios-smoke-screens.py .github/workflows/ios-synthetic-smoke.yml; do
    allow+=(":(exclude)$path")
done
git diff --exit-code "$demo_commit" HEAD -- . "${allow[@]}" || die "Unexpected changes to public Demo"
printf 'demo=%s\nsdk=%s\ncodegen=%s\n' "$demo_commit" "$sdk_commit" "$codegen_commit" >"$out/public-commits.txt"
mkdir "$demo"
git archive "$demo_commit" | tar -x -C "$demo"
git archive HEAD "${overlay[@]}" | tar -x -C "$demo"
git rev-parse HEAD >"$out/demo-smoke-overlay-commit.txt"
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
      :maduikit-theme:publishAndroidReleasePublicationToMadUIKitLocalRepository \
      :maduikit-components:publishAndroidReleasePublicationToMadUIKitLocalRepository \
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
verify_aar() (
    cd "$demo"
    ./gradlew --no-daemon :composeApp:verifyStagedAndroidSdk
)
runlog android-receipt verify_aar
grep -E '^Verified external module com[.]mad[.]maduikit:' "$work/android-receipt.log" >"$out/staged-android-aars.txt"
runlog simulator-boot xcrun simctl bootstatus "$sim" -b
xcargs=(
  -project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo
  -configuration Debug -destination "platform=iOS Simulator,id=$sim"
  -derivedDataPath "$work/derived-data" -parallel-testing-enabled NO
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
)
runlog xcode-build xcodebuild "${xcargs[@]}" build-for-testing

app="$work/derived-data/Build/Products/Debug-iphonesimulator/MadUIKitDemo.app"
bundle='dev.maduikit.demo'
[[ -f "$app/Info.plist" ]] || die "Simulator app not found"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")" == "$bundle" ]] || die "Unexpected simulator bundle"
python3 - "$app/Info.plist" <<'PYPLIST' | tee "$out/built-info-plist-check.txt"
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    plist = plistlib.load(f)
if plist.get("CADisableMinimumFrameDurationOnPhone") is not True:
    raise SystemExit("Required CADisableMinimumFrameDurationOnPhone missing or not Boolean true")
print("Built simulator Info.plist: CADisableMinimumFrameDurationOnPhone=true (Boolean verified).")
PYPLIST
# Gate on two distinctive gradient hues from the exact public generated fixture.
# Both retained screenshot artifacts must show the same synthetic gradient fixture.
cat >"$work/inspect.swift" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
let u = URL(fileURLWithPath: CommandLine.arguments[1])
guard let s = CGImageSourceCreateWithURL(u as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(s, 0, nil),
      let srgb = CGColorSpace(name: CGColorSpace.sRGB),
      let c = CGContext(data: nil, width: 180, height: 360, bitsPerComponent: 8, bytesPerRow: 720,
                        space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                        CGBitmapInfo.byteOrder32Big.rawValue),
      let data = c.data?.assumingMemoryBound(to: UInt8.self) else { exit(2) }
c.draw(image, in: CGRect(x: 0, y: 0, width: 180, height: 360))
var rows = 0
for y in 0..<360 {
    var violet = 0
    var teal = 0
    for x in 68..<112 {
        let i = (y * 180 + x) * 4
        let r = Int(data[i]), g = Int(data[i+1]), b = Int(data[i+2])
        if abs(r-84) < 27 && abs(g-38) < 27 && abs(b-145) < 27 { violet += 1 }
    }
    for x in 129..<172 {
        let i = (y * 180 + x) * 4
        let r = Int(data[i]), g = Int(data[i+1]), b = Int(data[i+2])
        if abs(r-13) < 30 && abs(g-107) < 30 && abs(b-107) < 30 { teal += 1 }
    }
    if violet >= 8 && teal >= 6 { rows += 1 }
}
print("image=\(image.width)x\(image.height) gradient_marker_rows=\(rows)")
exit(rows >= 8 ? 0 : 1)
SWIFT
runlog marker-compile xcrun swiftc "$work/inspect.swift" -o "$work/inspect-png"
result="$work/book-tabs.xcresult"
runlog xcuitest xcodebuild "${xcargs[@]}" -resultBundlePath "$result" \
  -only-testing:MadUIKitDemoUITests/BookFilterUITests/testFavoritesViaNativeTap test-without-building
xcrun xcresulttool get test-results summary --path "$result" >"$out/xcuitest-summary.json"
exports="$work/attachments"
mkdir "$exports"
xcrun xcresulttool export attachments --path "$result" --output-path "$exports"
python3 "$root/scripts/export-ios-smoke-screens.py" "$exports" "$out"
for state in before after; do
    img="$out/MadUIKit-iOS-Books-$state.png"
    "$work/inspect-png" "$img" >>"$out/gradient-proof.txt"
    sips -g pixelWidth -g pixelHeight "$img" >>"$out/screenshot-dimensions.txt"
done
(cd "$out" && shasum -a 256 MadUIKit-iOS-Books-before.png MadUIKit-iOS-Books-after.png > screenshot.sha256)
