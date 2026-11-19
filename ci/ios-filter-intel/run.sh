#!/usr/bin/env bash
set -euo pipefail
[[ $(uname -s) == Darwin && $(uname -m) == x86_64 ]] || { echo 'Standard Intel macOS required'; exit 2; }
root="$(pwd -P)"
out="${RUNNER_TEMP:?}/mad-ios-filter-evidence"
work="$(mktemp -d "$RUNNER_TEMP/mad-ios-verified.XXXXXX")"
mkdir -p "$out" "$work/sdk" "$work/demo"
sdk="$work/sdk"; demo="$work/demo"; stage="$work/maven-stage"
codegen="$root/ci-input/codegen"
test "$(git -C "$root/ci-input/sdk" rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
test "$(git -C "$codegen" rev-parse HEAD)" = 4c12c7b6e9998b7d832b766409c321bbaa12903b
git merge-base --is-ancestor 8f386c28d1b5709f3ce57adae2912993c1f8222f HEAD
git diff --exit-code 8f386c28d1b5709f3ce57adae2912993c1f8222f HEAD -- . ':!ci/ios-verified-consumer' ':!.github/workflows/ios-verified-consumer.yml' ':!docs/IOS-VERIFIED-CONSUMER.md' ':!ci/ios-filter-intel' ':!.github/workflows/ios-filter-intel.yml'
git -C "$root/ci-input/sdk" archive HEAD | tar -x -C "$sdk"
git archive 8f386c28d1b5709f3ce57adae2912993c1f8222f | tar -x -C "$demo"
printf 'probe=%s\ndemo=%s\nsdk=%s\ncodegen=%s\n' "$(git rev-parse HEAD)" 8f386c28d1b5709f3ce57adae2912993c1f8222f 19c8c1b1fbe75b7d6a6118fdab42048948de091b 4c12c7b6e9998b7d832b766409c321bbaa12903b > "$out/commits.txt"
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
# Apply only the reviewed public synthetic test host and XCTest project adapter.
cp "$root/ci/ios-filter-intel/DemoScreen.kt" "$demo/composeApp/src/commonMain/kotlin/dev/maduikit/demo/DemoScreen.kt"
cp "$root/ci/ios-filter-intel/BookFilterUITests.swift" "$demo/iosApp/BookFilterUITests.swift"
cp "$root/ci/ios-filter-intel/project.pbxproj" "$demo/iosApp/MadUIKitDemo.xcodeproj/project.pbxproj"
cp "$root/ci/ios-filter-intel/MadUIKitDemo.xcscheme" "$demo/iosApp/MadUIKitDemo.xcodeproj/xcshareddata/xcschemes/MadUIKitDemo.xcscheme"
printf 'Public synthetic filter host overlay from ci/ios-filter-intel; SDK and generated Kotlin unchanged.\n' >> "$out/source-adapter.txt"
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
xcargs=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo
  -configuration Debug -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$work/derived"
  -parallel-testing-enabled NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO)
runlog xcode-build xcodebuild "${xcargs[@]}" build-for-testing
app="$work/derived/Build/Products/Debug-iphonesimulator/MadUIKitDemo.app"
xcrun lipo -archs "$app/MadUIKitDemo" | tee "$out/app-architecture.txt"
grep -Fx x86_64 "$out/app-architecture.txt"
result="$work/filter-tabs.xcresult"
runlog xcuitest xcodebuild "${xcargs[@]}" -resultBundlePath "$result" \
  -only-testing:MadUIKitDemoUITests/BookFilterUITests/testSelectionAndDisabledTap test-without-building
xcrun xcresulttool get test-results summary --path "$result" > "$out/xcuitest-summary.json"
mkdir "$work/attachments"
xcrun xcresulttool export attachments --path "$result" --output-path "$work/attachments"
python3 "$root/ci/ios-filter-intel/export-ios-smoke-screens.py" "$work/attachments" "$out"
runlog inspector xcrun swiftc "$root/ci/ios-verified-consumer/inspect.swift" -o "$work/inspect-png"
for state in before after disabled; do
  "$work/inspect-png" "$out/MadUIKit-iOS-Books-$state.png" >> "$out/gradient-proof.txt"
done
# Retain original receipt bytes from a fresh independently verified generation too.
python3 "$codegen/scripts/generate-verified.py" --launcher "$codegen/build/install/MadUIKitCodegen/bin/MadUIKitCodegen" \
 --input "$codegen/fixtures/figma/gradient.file-nodes.json" --node 3:1 --fit-width --out "$out/bundle"
python3 "$demo/scripts/check-structure.py" --generated-source "$out/bundle/FigmaProfileScreen.generated.kt"
(cd "$out" && shasum -a 256 MadUIKit-iOS-Books-*.png bundle/* > evidence.sha256)
printf 'PASS: actual XCUI selection, disabled semantics and disabled center-tap no-op. Public synthetic Intel simulator only.\n' > "$out/result.txt"
