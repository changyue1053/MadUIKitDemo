#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
parent=90a19c5f7ce451f505dd6f0b769d4014b86fc9a7
pin=99d7c390c718c1d115b491c8de3d64de443bad7b
root="$(pwd -P)"
tmp="$(cd "${RUNNER_TEMP:?}" && pwd -P)"
out="$tmp/mad-alpha28-stage-receipt"
mkdir "$out"
w="$(mktemp -d "$tmp/mad-alpha28-stage.XXXXXX")"
gate=pin
finish() {
  local rc=$? result
  trap - EXIT
  result="$(mktemp "$out/.pending.XXXXXX")"
  python3 "$here/receipt.py" emit "$w" "$result" "$rc" "$gate"
  if ! rm -rf -- "$w" || [[ -e "$w" ]]; then
     rc=1
     python3 "$here/receipt.py" emit "$w" "$result" 1 scratch-cleanup-failed
  fi
  mv "$result" "$out/alpha28-stage.json"
  exit "$rc"
}
trap finish EXIT
exec > "$w/private.log" 2>&1
test "${GITHUB_REF:?}" = refs/heads/ci/sdk-alpha28-maven-no-export
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?}"
test "$(git rev-parse HEAD^)" = "$parent"
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
expected="$(cat <<'FILES'
.github/workflows/sdk-alpha28-maven-no-export.yml
ci/sdk-alpha28-stage/adopter/composeApp/build.gradle.kts
ci/sdk-alpha28-stage/adopter/composeApp/src/commonMain/kotlin/StageCaller.kt
ci/sdk-alpha28-stage/adopter/settings.gradle.kts
ci/sdk-alpha28-stage/bounded.py
ci/sdk-alpha28-stage/receipt.py
ci/sdk-alpha28-stage/run.sh
ci/sdk-alpha28-stage/stage-file-template.txt
ci/sdk-alpha28-stage/verify-stage.py
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
gate=exact-source
sdk="$w/sdk"; stage="$w/stage"; adopter="$w/app"
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
python3 "$here/bounded.py" 960 "$w/publish.log" bash gradlew "${flags[@]}" "-PmaduikitStagingDir=$stage" "${tasks[@]}"
gate=stage-before
python3 "$here/verify-stage.py" "$stage" > "$w/stage-before.json"
mkdir "$adopter"
cp -R "$here/adopter/." "$adopter/"
cp "$sdk/gradlew" "$adopter/"; cp -R "$sdk/gradle" "$adopter/"
cd "$adopter"
export GRADLE_USER_HOME="$w/adopter-gradle"
test ! -e "$GRADLE_USER_HOME"
gate=android-compile
python3 "$here/bounded.py" 420 "$w/android.log" bash gradlew "${flags[@]}" "-PmadStage=$stage" "-PmadCompileConfiguration=debugCompileClasspath" :composeApp:verifyStageGraph :composeApp:compileDebugKotlinAndroid
grep -Fxq '> Task :composeApp:compileDebugKotlinAndroid' "$w/android.log"
cp composeApp/build/reports/sdk-stage-android.tsv "$w/android.tsv"
gate=ios-simulator-compile
python3 "$here/bounded.py" 420 "$w/ios-simulator.log" bash gradlew "${flags[@]}" "-PmadStage=$stage" "-PmadCompileConfiguration=iosSimulatorArm64CompileKlibraries" :composeApp:verifyStageGraph :composeApp:compileKotlinIosSimulatorArm64
grep -Fxq '> Task :composeApp:compileKotlinIosSimulatorArm64' "$w/ios-simulator.log"
cp composeApp/build/reports/sdk-stage-iossimulatorarm64.tsv "$w/iossimulatorarm64.tsv"
gate=stage-after
python3 "$here/verify-stage.py" "$stage" > "$w/stage-after.json"
gate=validate-bindings
python3 "$here/receipt.py" qualify "$w"
gate=verified
