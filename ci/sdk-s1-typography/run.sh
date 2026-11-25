#!/usr/bin/env bash
set -euo pipefail
root="$(pwd -P)"
ci="$root/ci/sdk-s1-typography"
out="${RUNNER_TEMP:?}/mad-s1-evidence"
mkdir "$out"
gate=preflight
work="$(mktemp -d "$RUNNER_TEMP/mad-s1.XXXXXX")"
work="$(cd "$work" && pwd -P)"
trap 'rc=$?; printf "gate=%s\nexit=%s\nscope=synthetic iOS simulator alpha12 form focus, error recovery and submit; no Android/Harmony execution, device, or packaging\n" "$gate" "$rc" > "$out/result.txt"; exit "$rc"' EXIT
runlog(){
  gate="$1"; local bound="$2"; shift 2
  printf 'Checkpoint: %s (%s s)\n' "$gate" "$bound"
  local rc=0 detail=command-failed logfile="$work/$gate.log"
  python3 "$ci/bounded.py" "$bound" "$logfile" "$@" || rc=$?
  if (( rc == 124 )); then detail=timeout
  elif grep -Fq "was not found in any of the following sources" "$logfile"; then detail=plugin-marker-not-found
  elif grep -Eiq 'could not (resolve|download|GET)|PKIX path building failed' "$logfile"; then detail=public-dependency-resolution
  elif (( rc == 0 )); then detail=passed
  fi
  printf '%s\t%s\t%s\n' "$gate" "$rc" "$detail" >> "$out/checkpoints.tsv"
  return "$rc"
}
base=1a814b05d5d1262e5023779cc137d1e2aee3d391
branch=refs/heads/ci/sdk-alpha12-ios-form
test "${GITHUB_REF:?}" = "$branch"
pin=dee2ece216db4b36fa28400dcc767a241fc4f367
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?}"
test "$(git rev-parse HEAD^)" = "$base"
changed="$(git diff --name-only "$base" HEAD | LC_ALL=C sort)"
expected="$(cat <<'FILES'
.github/workflows/sdk-s1-typography.yml
ci/sdk-s1-typography/run.sh
ci/sdk-s1-typography/runtime/iosApp/BookFilterUITests.swift
ci/sdk-s1-typography/runtime/run-host.sh
ci/sdk-s1-typography/runtime/runtime-proof.py
ci/sdk-s1-typography/runtime/same-job-framework.py
ci/sdk-s1-typography/ui-adopter/composeApp/build.gradle.kts
ci/sdk-s1-typography/ui-adopter/composeApp/src/commonMain/kotlin/TrialForm.kt
ci/sdk-s1-typography/ui-adopter/composeApp/src/iosMain/kotlin/FixtureViewController.kt
ci/sdk-s1-typography/verify-stage.py
FILES
)"
test "$changed" = "$expected"
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
gate=arm64-host
host="$(uname -s)-$(uname -m)"
macos="$(sw_vers -productVersion)"
test "$host-${ImageOS:?}" = Darwin-arm64-macos26
[[ "$macos" == 26.* ]]
[[ "${ImageVersion:?}" =~ ^[0-9]{8}\.[0-9]{4}\.[0-9]+$ && "$ImageVersion" != 20261118.0550.1 ]]
printf '%s\n' "demo=$(git rev-parse HEAD)" "sdk=$pin" "image=${ImageVersion:?}" "host=$host" "macos=$macos" > "$out/source.txt"
gate=link-host-memory
host_memory_bytes="$(sysctl -n hw.memsize)"
[[ "$host_memory_bytes" =~ ^[1-9][0-9]{9,11}$ ]]
printf 'physicalMemoryBytes=%s\n' "$host_memory_bytes" > "$out/link-host-memory.txt"
(( host_memory_bytes >= 7000000000 ))
gate=stock-apple-toolchain
java -version > "$out/java.txt" 2>&1
grep -E 'version "17\.' "$out/java.txt"
export DEVELOPER_DIR=/Applications/Xcode_26.4.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
xcodebuild -version > "$out/xcode.txt"
grep -Fx 'Xcode 26.4.1' "$out/xcode.txt"
grep -Fx 'Build version 17E202' "$out/xcode.txt"
for apple in iphoneos iphonesimulator; do
  sdk_path="$(xcrun --sdk "$apple" --show-sdk-path)"
  test -d "$sdk_path"
  sdk_path="$(cd "$sdk_path" && pwd -P)"
  developer_path="$(cd "$DEVELOPER_DIR" && pwd -P)"
  [[ "$sdk_path" == "$developer_path"/Platforms/* ]]
  sdk_version="$(xcrun --sdk "$apple" --show-sdk-version)"
  test "$sdk_version" = 26.4
  printf '%s=%s\n' "$apple" "$sdk_version" >> "$out/xcode.txt"
done
gate=no-active-guest-before-build
xcrun simctl list devices -j | python3 "$ci/runtime/same-job-framework.py" check-guests
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required}}"
gate=android-sdk36-stock
test -f "$ANDROID_HOME/platforms/android-36/android.jar"
gate=exact-sdk-source
sdk="$work/sdk"
stage="$work/stage"
mkdir "$sdk"
git -C ci-input/sdk archive HEAD | tar -x -C "$sdk"
cd "$sdk"
python3 scripts/verify-preview-source.py
grep -Fx 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip' gradle/wrapper/gradle-wrapper.properties
grep -Fx 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' gradle/wrapper/gradle-wrapper.properties
export GRADLE_USER_HOME="$work/producer-gradle"
flags=(--no-daemon --console=plain --no-build-cache -Pandroid.useAndroidX=true)
runlog publisher-help 240 bash gradlew "${flags[@]}" help
touch "$out/publisher-configured"
test ! -e "$stage"
tasks=()
for module in maduikit-theme maduikit-components; do
  for leaf in KotlinMultiplatform IosSimulatorArm64; do
    tasks+=(":${module}:publish${leaf}PublicationToMadUIKitLocalRepository")
  done
done
runlog publish 720 bash gradlew "${flags[@]}" "-PmaduikitStagingDir=$stage" "${tasks[@]}"
gate=stage-verify
python3 "$ci/verify-stage.py" "$stage" > "$out/stage-before.json"
gate=ui-adopter-source
adopter="$work/ui-adopter"
mkdir "$adopter"
cp -R "$ci/ui-adopter/." "$adopter/"
cp "$sdk/gradlew" "$adopter/"; cp -R "$sdk/gradle" "$adopter/"
cd "$adopter"
export GRADLE_USER_HOME="$work/ui-adopter-gradle"
test ! -e "$GRADLE_USER_HOME"
options=("-PmadStage=$stage" -PmadApple=true)
shasum -a 256 composeApp/src/commonMain/kotlin/TrialForm.kt > "$out/ui-caller.sha256"
ios_probe(){
  gate="$1"; local bound="$2"; shift 2
  local rc=0 logfile="$work/$gate.log"
  printf 'Checkpoint: %s (%s s)\n' "$gate" "$bound"
  python3 "$ci/bounded.py" "$bound" "$logfile" "$@" || rc=$?
  python3 "$ci/sanitize-ios.py" "$gate" "$rc" "$logfile" > "$out/$gate.json"
  return "$rc"
}
conf=iosSimulatorArm64CompileKlibraries
ios_probe ios-resolve 240 bash gradlew "${flags[@]}" "${options[@]}" "-PmadCompileConfiguration=$conf" :composeApp:verifySdkCompile
cp "composeApp/build/reports/sdk-maduikit-components-$conf.txt" "$out/ui-$conf.txt"
ios_probe ios-compile 300 bash gradlew "${flags[@]}" "${options[@]}" :composeApp:compileKotlinIosSimulatorArm64
ios_probe ios-framework 420 bash gradlew "${flags[@]}" "${options[@]}" --stacktrace --max-workers=1 \
  "-Dorg.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=384m -XX:-HeapDumpOnOutOfMemoryError" \
  --init-script "$ci/verify-link-heap.init.gradle" :composeApp:linkDebugFrameworkIosSimulatorArm64
gate=linked-heap-proof
python3 - "$out/ios-framework.json" <<'PYHEAP'
import json, sys
from pathlib import Path
d = json.loads(Path(sys.argv[1]).read_text())
v = d.get("effectiveLinkHeapBytes")
if type(v) is not int or not 3758096384 <= v <= 4563402752:
    raise SystemExit("Missing or out-of-bounds in-task heap receipt")
PYHEAP
gate=ui-ios-framework-validation
framework_rel=composeApp/build/bin/iosSimulatorArm64/debugFramework/MadUIKitS1Adopter.framework/MadUIKitS1Adopter
framework="$adopter/$framework_rel"
test -s "$framework"
xcrun lipo -archs "$framework" | grep -Fx arm64
xcrun otool -l "$framework" | awk '/cmd LC_BUILD_VERSION/ { active=1; next } active && $1=="platform" {print $2; active=0}' | sort -u > "$out/ui-ios-platform.txt"
grep -Ex 'IOSSIMULATOR|7' "$out/ui-ios-platform.txt"
test "$(wc -l < "$out/ui-ios-platform.txt" | tr -d ' ')" = 1
shasum -a 256 "$framework_rel" > "$out/ui-ios-framework.sha256"
gate=stage-immutable-after-ui-adopter
python3 "$ci/verify-stage.py" "$stage" > "$out/stage-after-ui.json"
cmp "$out/stage-before.json" "$out/stage-after-ui.json"
gate=same-job-framework-size-diagnostic
python3 "$ci/runtime/same-job-framework.py" measure "$(dirname "$framework")" > "$out/local-framework-sizes.json"
gate=same-job-framework-provenance
proof="$work/same-job-framework.json"
sha(){ shasum -a 256 "$1" | awk '{print $1}'; }
python3 "$ci/runtime/same-job-framework.py" record "$(dirname "$framework")" "$proof" \
  "$(awk '{print $1}' "$out/ui-ios-framework.sha256")" \
  "$(sha "$out/ui-iosSimulatorArm64CompileKlibraries.txt")" \
  "$(awk '{print $1}' "$out/ui-caller.sha256")" "$(sha "$out/stage-before.json")"
gate=same-job-synthetic-native-host
(cd "$root"; bash "$ci/runtime/run-host.sh" "$(dirname "$framework")" "$proof")
gate=verified-synthetic-alpha12-ios-form-entry
