#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
root="$(pwd -P)"
base=33ed243162032675caaf357557ae9fe5e1eea010
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
(cd "$sdk" && runlog stage 900 bash gradlew --no-daemon --console=plain "-PmaduikitStagingDir=$stage" \
  :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository \
  :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-components:publishIosSimulatorArm64PublicationToMadUIKitLocalRepository)
python3 - "$stage" "$out/klib-selection.json" <<'PYPIN'
from pathlib import Path
import hashlib,json,re,sys
sdkStage=Path(sys.argv[1])/"com/mad/maduikit"
historical={
 "44747981892/14634892882": ["feade7bdf748655ceca2165d5a3b87f45bb0f8107d27e247b0e03b60c204ed56","220b6efcc49281e02ffb069e2bd0d2cd10a6da209d5561b1aea9a47ac4a76674"],
 "44752961793/14636563015": ["98571ad65f3eb368a7a560d5918b2b49f4968294c3fa93afbf2439b7cad01394","08ac92407830bc980b3fc80da0bddf58d7f461b24b8c3275516d4b5b0d399062"]}
records=[]
for kind in ("components","theme"):
 module=f"maduikit-{kind}-iossimulatorarm64"
 path=sdkStage/module/"0.1.0-alpha01"
 name=f"{module}-0.1.0-alpha01.klib"
 row=dict(module=module,expectedFromCurrentModuleSha256=None,actualSha256=None,verified=False)
 try:
    binary=path/name
    meta=json.loads((path/f"{module}-0.1.0-alpha01.module").read_text())
    variants=[v for v in meta["variants"] if v["attributes"].get("org.gradle.usage")=="kotlin-api"
        and v["attributes"].get("org.jetbrains.kotlin.native.target")=="ios_simulator_arm64"]
    variant,=variants
    rec,=[f for f in variant["files"] if f["url"]==name]
    row["expectedFromCurrentModuleSha256"]=rec["sha256"] if re.fullmatch("[a-f0-9]{64}",rec["sha256"]) else None
    row["actualSha256"]=hashlib.sha256(binary.read_bytes()).hexdigest()
    row["verified"]=row["actualSha256"]==row["expectedFromCurrentModuleSha256"] and binary.stat().st_size==rec["size"]
 except (OSError,ValueError,KeyError,TypeError):
    pass
 records.append(row)
actual=[r["actualSha256"] for r in records]
receipt=dict(expectedSdkPin="19c8c1b1fbe75b7d6a6118fdab42048948de091b",scope="public simulator staging",
             referencePairs=historical,matchesHistoricalPair=[k for k,v in historical.items() if v==actual],
             policy="require current published metadata and resolved bytes; historical reproducible pin not implied",records=records)
Path(sys.argv[2]).write_text(json.dumps(receipt,indent=2)+"\n")
if not all(r["verified"] for r in records):
 raise SystemExit("Invalid current SDK staged KLIB digest; stop before test")
PYPIN
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
derived="$work/derived"
args=(-project "$demo/iosApp/MadUIKitDemo.xcodeproj" -scheme MadUIKitDemo -configuration Debug
 -destination "generic/platform=iOS Simulator" -derivedDataPath "$derived" -parallel-testing-enabled NO
 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO)
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
runlog test 420 xcodebuild -xctestrun "$test_run" -destination "platform=iOS Simulator,id=$sim" \
 -parallel-testing-enabled NO -resultBundlePath "$work/result.xcresult" \
 -only-testing:MadUIKitDemoUITests/BookFilterUITests/testIndependentConsumer test-without-building
xcrun xcresulttool get test-results summary --path "$work/result.xcresult" > "$out/test-summary.json"
mkdir "$work/attachments"
xcrun xcresulttool export attachments --path "$work/result.xcresult" --output-path "$work/attachments"
python3 "$ci/frame-validator.py" verify "$validator" "$out/frame-validator.json"
python3 "$ci/runtime-proof.py" "$out" "$work/attachments" "$validator"
