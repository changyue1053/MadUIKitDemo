#!/usr/bin/env bash
set -euo pipefail
root="$(pwd -P)"
ci="$root/ci/sdk-s1-typography"
historic="$root/ci/ios-arm-sim-adoption"
out="${RUNNER_TEMP:?}/mad-s1-runtime-receipt"
mkdir "$out"
work="$(mktemp -d "$RUNNER_TEMP/mad-s1-runtime.XXXXXX")"
work="$(cd "$work" && pwd -P)"
gate=stock-arm-host
trap 'rc=$?; printf "gate=%s\nexit=%s\nscope=synthetic iosSimulatorArm64 only\n" "$gate" "$rc" > "$out/result.txt"; exit "$rc"' EXIT
runlog(){ gate="$1"; local t="$2"; shift 2; python3 "$ci/bounded.py" "$t" "$work/$gate.log" "$@"; }
test "${GITHUB_REF:?}" = refs/heads/ci/sdk-alpha07-ios-controls
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?}"
test "$(uname -s)-$(uname -m)-${ImageOS:?}" = Darwin-arm64-macos26
image="${ImageVersion:?}"
[[ "$image" =~ ^[0-9]{8}\.[0-9]{4}\.[0-9]+$ && "$image" != 20261118.0550.1 ]]
export DEVELOPER_DIR=/Applications/Xcode_26.4.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
xcodebuild -version > "$out/xcode.txt"
grep -Fx 'Xcode 26.4.1' "$out/xcode.txt"
grep -Fx 'Build version 17E202' "$out/xcode.txt"
test "$(xcrun --sdk iphonesimulator --show-sdk-version)" = 26.4
printf 'image=%s\nhost=Darwin-arm64\nsimulatorSdk=26.4\n' "$image" >> "$out/xcode.txt"
gate=local-framework-and-arch
cp -R "$ci/runtime/iosApp" "$work/iosApp"
cp -R "$ci/runtime/scripts" "$work/scripts"
local_framework="${1:?}"
proof="${2:?}"
python3 "$ci/runtime/same-job-framework.py" verify "$local_framework" "$proof"
mkdir "$work/framework"
framework="$work/framework/MadUIKitS1Adopter.framework"
gate=local-framework-disk
python3 "$ci/runtime/same-job-framework.py" check-disk "$local_framework" "$work/framework" > "$out/local-framework-disk.json"
gate=local-framework-copy
cp -R "$local_framework" "$framework"
python3 "$ci/runtime/same-job-framework.py" verify "$framework" "$proof"
printf '%s  %s\n' \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["callerSha256"])' "$proof")" \
  "$ci/ui-adopter/composeApp/src/iosMain/kotlin/ControlsCatalog.kt" | shasum -a 256 -c
binary="$framework/MadUIKitS1Adopter"
xcrun lipo -archs "$binary" | grep -Fx arm64
xcrun otool -l "$binary" | awk '/cmd LC_BUILD_VERSION/ { active=1; next } active && $1=="platform" {print $2; active=0}' | sort -u > "$out/framework-platform.txt"
grep -Ex 'IOSSIMULATOR|7' "$out/framework-platform.txt"
test "$(wc -l < "$out/framework-platform.txt" | tr -d ' ')" = 1
validator="$work/validate-imageio-frame"
runlog validator-build 120 xcrun --sdk macosx swiftc -O -target arm64-apple-macosx26.0 "$historic/boot-frame.swift" -o "$validator"
runlog validator-prove 35 python3 "$historic/frame-validator.py" prove "$validator" "$historic/boot-frame.swift" "$out/frame-validator.json"
derived="$work/derived"
runlog build-host 420 xcodebuild -project "$work/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug \
 -destination "generic/platform=iOS Simulator" -derivedDataPath "$derived" -parallel-testing-enabled NO \
 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build-for-testing
gate=host-validation
python3 "$ci/runtime/same-job-framework.py" verify "$framework" "$proof"
products="$derived/Build/Products"
plist="$products/Debug-iphonesimulator/MadUIKitDemo.app/Info.plist"
python3 - "$plist" "$out/app-plist.json" <<'PY'
import json, plistlib, sys
from pathlib import Path
path, out=map(Path,sys.argv[1:])
p=plistlib.loads(path.read_bytes())
if p.get("CADisableMinimumFrameDurationOnPhone") is not True or p.get("CFBundleIdentifier")!="dev.mad.synthetic.typography.ios":
    raise SystemExit("Built host plist lacks exact required Boolean or app ID")
out.write_text(json.dumps({"bundleId":p["CFBundleIdentifier"],"CADisableMinimumFrameDurationOnPhone":True})+"\n")
PY
xcrun lipo -archs "$products/Debug-iphonesimulator/MadUIKitDemo.app/MadUIKitDemo" | grep -Fx arm64
test_run="$(python3 - "$products" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
files=list(root.glob("*.xctestrun"))
if len(files)!=1 or files[0].is_symlink() or not files[0].is_file():
    raise SystemExit("Missing unique built XCTest run")
print(files[0])
PY
)"
gate=guest-select
xcrun simctl list devices -j | python3 "$ci/runtime/same-job-framework.py" check-guests
xcrun simctl list -j | python3 "$historic/guest-inventory.py" --candidates "$out/guest-candidates.json" > "$out/guest-selected.json"
sim="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "$out/guest-selected.json")"
runlog boot 300 xcrun simctl bootstatus "$sim" -b
xcrun simctl list -j | python3 "$historic/guest-inventory.py" "$sim" > "$out/guest-booted.json"
runlog boot-frame 25 xcrun simctl io "$sim" screenshot "$work/boot-only.png"
python3 "$historic/frame-validator.py" verify "$validator" "$out/frame-validator.json"
runlog frame-check 45 "$validator" "$work/boot-only.png" boot
gate=guest-recheck
xcrun simctl list -j | python3 "$historic/guest-inventory.py" "$sim" > "$work/guest-before-test.json"
cmp "$out/guest-booted.json" "$work/guest-before-test.json"
xc="$work/ui.xcresult"
runlog test 360 xcodebuild -xctestrun "$test_run" -destination "platform=iOS Simulator,id=$sim" \
 -parallel-testing-enabled NO -resultBundlePath "$xc" \
 -only-testing:MadUIKitDemoUITests/BookFilterUITests/testAlpha07ControlsCatalog test-without-building
gate=proven-original-attachments
xcrun xcresulttool get test-results summary --path "$xc" > "$work/summary.json"
mkdir "$work/attachments" "$work/verified"
xcrun xcresulttool export attachments --path "$xc" --output-path "$work/attachments"
python3 "$ci/runtime/runtime-proof.py" "$work/summary.json" "$work/attachments" "$work/verified" "$proof"
for name in S1-alpha07-controls-before S1-alpha07-controls-after; do
  runlog "imageio-$name" 45 "$validator" "$work/verified/$name.png" books
done
cp "$work/verified/"{S1-alpha07-controls-before.png,S1-alpha07-controls-after.png,runtime.json} "$out/"
gate=verified-synthetic-alpha07-ios-controls
