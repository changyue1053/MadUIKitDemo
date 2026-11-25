#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
parent=b4195b106312f4a42b2b7fc1d888bf4e8b91da86
pin=99d7c390c718c1d115b491c8de3d64de443bad7b
proven="$here/../sdk-alpha28-stage"
tmp="$(cd "${RUNNER_TEMP:?}" && pwd -P)"
out="$tmp/mad-alpha28-two-adopters-receipt"
mkdir "$out"
w="$(mktemp -d "$tmp/mad-alpha28-two-adopters.XXXXXX")"
gate=pin
finish() {
  local rc=$? result
  trap - EXIT
  result="$(mktemp "$out/.pending.XXXXXX")"
  # A receipt writer failure must never skip cleanup or upload partial output.
  local emit_ok=1
  python3 "$here/receipt.py" emit "$w" "$result" "$rc" "$gate" || emit_ok=0
  if ! rm -rf -- "$w" || [[ -e "$w" ]]; then
     rc=1
     emit_ok=1
     python3 "$here/receipt.py" emit "$w" "$result" 1 scratch-cleanup-failed || emit_ok=0
  fi
  if (( emit_ok )); then
    mv "$result" "$out/alpha28-two-adopters.json"
  else
    rm -f -- "$result"
    rc=1
  fi
  exit "$rc"
}
trap finish EXIT
exec > "$w/private.log" 2>&1
test "${GITHUB_REF:?}" = refs/heads/ci/sdk-alpha28-two-adopters
test "${GITHUB_REPOSITORY:?}" = changyue1053/MadUIKitDemo
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?}"
test "$(git rev-parse HEAD^)" = "$parent"
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
expected="$(cat <<'FILES'
.github/workflows/sdk-alpha28-two-adopters-no-export.yml
ci/sdk-alpha28-two-adopters/atlas/composeApp/build.gradle.kts
ci/sdk-alpha28-two-adopters/atlas/composeApp/src/commonMain/kotlin/AtlasTransfer.kt
ci/sdk-alpha28-two-adopters/atlas/settings.gradle.kts
ci/sdk-alpha28-two-adopters/orchid/composeApp/build.gradle.kts
ci/sdk-alpha28-two-adopters/orchid/composeApp/src/commonMain/kotlin/OrchidCatalog.kt
ci/sdk-alpha28-two-adopters/orchid/settings.gradle.kts
ci/sdk-alpha28-two-adopters/receipt.py
ci/sdk-alpha28-two-adopters/run.sh
FILES
)"
test "$(git diff --name-only "$parent" HEAD | LC_ALL=C sort)" = "$expected"
gate=host-profile
test "$(uname -s)-$(uname -m)-${ImageOS:?}" = Darwin-arm64-macos26
[[ "$(sw_vers -productVersion)" == 26.* ]]
[[ "${ImageVersion:?}" =~ ^[0-9]{8}\.[0-9]{4}\.[0-9]+$ && "$ImageVersion" != 20261118.0550.1 ]]
gate=stock-java
java -version > "$w/java.txt" 2>&1
grep -Eq 'version "17\.' "$w/java.txt"
gate=stock-xcode
export DEVELOPER_DIR=/Applications/Xcode_26.4.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
xcodebuild -version > "$w/xcode.txt"
grep -Fxq 'Xcode 26.4.1' "$w/xcode.txt"
grep -Fxq 'Build version 17E202' "$w/xcode.txt"
for apple in iphoneos iphonesimulator; do
    sdk_path="$(xcrun --sdk "$apple" --show-sdk-path)"
    [[ "$(cd "$sdk_path" && pwd -P)" == "$(cd "$DEVELOPER_DIR" && pwd -P)"/Platforms/* ]]
    test "$(xcrun --sdk "$apple" --show-sdk-version)" = 26.4
done
gate=stock-sdk36
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
test -n "$ANDROID_HOME" && test -r "$ANDROID_HOME/platforms/android-36/android.jar"
disk_ok() {
    local avail
    avail="$(df -Pk "$w" | awk 'NR == 2 { print $4 }')"
    [[ "$avail" =~ ^[0-9]+$ ]] && (( avail >= $1 ))
}
gate=disk-before-producer
disk_ok 7340032
gate=exact-source
sdk="$w/sdk"; stage="$w/stage"
mkdir "$sdk"
git -C ci-input/sdk archive "$pin" | tar -x -C "$sdk"
cd "$sdk"
python3 scripts/verify-preview-source.py
grep -Fxq 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip' gradle/wrapper/gradle-wrapper.properties
grep -Fxq 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' gradle/wrapper/gradle-wrapper.properties
flags=(--no-daemon --console=plain --no-build-cache --max-workers=1 -Pandroid.useAndroidX=true)
tasks=()
for module in maduikit-theme maduikit-components; do
  for leaf in KotlinMultiplatform AndroidRelease IosSimulatorArm64 IosArm64; do
    tasks+=(":${module}:publish${leaf}PublicationToMadUIKitLocalRepository")
  done
done
gate=publish
test ! -e "$stage"
export GRADLE_USER_HOME="$w/producer-gradle"
python3 "$proven/bounded.py" 960 "$w/publish.log" bash gradlew "${flags[@]}" "-PmaduikitStagingDir=$stage" "${tasks[@]}"
gate=stage-before
python3 "$proven/verify-stage.py" "$stage" > "$w/stage-before.json"
rm -rf -- "$w/producer-gradle"
for app in atlas orchid; do
    gate="$app-disk"
    disk_ok 4194304
    adopter="$w/$app"
    mkdir "$adopter"
    cp -R "$here/$app/." "$adopter/"
    cp "$sdk/gradlew" "$adopter/"; cp -R "$sdk/gradle" "$adopter/"
    cd "$adopter"
    export GRADLE_USER_HOME="$w/$app-gradle"
    test ! -e "$GRADLE_USER_HOME"
    gate="$app-android-compile"
    python3 "$proven/bounded.py" 360 "$w/$app-android.log" bash gradlew "${flags[@]}" "-PmadStage=$stage" "-PmadCompileConfiguration=debugCompileClasspath" :composeApp:verifyStageGraph :composeApp:compileDebugKotlinAndroid
    grep -Fxq '> Task :composeApp:compileDebugKotlinAndroid' "$w/$app-android.log"
    cp composeApp/build/reports/sdk-stage-android.tsv "$w/$app-android.tsv"
    gate="$app-ios-simulator-compile"
    python3 "$proven/bounded.py" 240 "$w/$app-iossimulatorarm64.log" bash gradlew "${flags[@]}" "-PmadStage=$stage" "-PmadCompileConfiguration=iosSimulatorArm64CompileKlibraries" :composeApp:verifyStageGraph :composeApp:compileKotlinIosSimulatorArm64
    grep -Fxq '> Task :composeApp:compileKotlinIosSimulatorArm64' "$w/$app-iossimulatorarm64.log"
    cp composeApp/build/reports/sdk-stage-iossimulatorarm64.tsv "$w/$app-iossimulatorarm64.tsv"
    rm -rf -- "$w/$app-gradle"
done
gate=stage-after
python3 "$proven/verify-stage.py" "$stage" > "$w/stage-after.json"
gate=validate-bindings
python3 "$here/receipt.py" qualify "$w"
gate=verified
