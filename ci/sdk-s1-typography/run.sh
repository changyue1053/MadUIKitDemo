#!/usr/bin/env bash
set -euo pipefail
root="$(pwd -P)"
ci="$root/ci/sdk-s1-typography"
out="${RUNNER_TEMP:?}/mad-s1-evidence"
mkdir "$out"
gate=preflight
work="$(mktemp -d "$RUNNER_TEMP/mad-s1.XXXXXX")"
trap 'rc=$?; printf "gate=%s\nexit=%s\nscope=synthetic Android and iOS compile only; no runtime or Harmony\n" "$gate" "$rc" > "$out/result.txt"; exit "$rc"' EXIT
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
base=3407dfb83f6753734de6149314a70b9406953730
branch=refs/heads/ci/sdk-s1-typography-intel-stage
test "${GITHUB_REF:?}" = "$branch"
pin=19c8c1b1fbe75b7d6a6118fdab42048948de091b
test "$(git rev-parse HEAD^)" = "$base"
git diff --exit-code "$base" HEAD -- . ':!ci/sdk-s1-typography/run.sh' ':!.github/workflows/sdk-s1-typography.yml'
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
gate=intel-host
host="$(uname -s)-$(uname -m)"
macos="$(sw_vers -productVersion)"
test "$host" = Darwin-x86_64
[[ "$macos" == 15.* ]]
gate=stock-apple-toolchain
java -version > "$out/java.txt" 2>&1
grep -E 'version "17\.' "$out/java.txt"
xcodebuild -version > "$out/xcode.txt"
grep -Eq '^Xcode 26([. ]|$)' "$out/xcode.txt"
for apple in iphoneos iphonesimulator; do
  sdk_path="$(xcrun --sdk "$apple" --show-sdk-path)"
  test -d "$sdk_path"
  printf '%s=%s\n' "$apple" "$(xcrun --sdk "$apple" --show-sdk-version)" >> "$out/xcode.txt"
done
printf '%s\n' "demo=$(git rev-parse HEAD)" "sdk=$pin" "image=${ImageVersion:?}" "host=$host" "macos=$macos" > "$out/source.txt"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required}}"
gate=android-sdk36-stock
test -f "$ANDROID_HOME/platforms/android-36/android.jar"
gate=source-overlay
sdk="$work/sdk"
stage="$work/stage"
mkdir "$sdk"
git -C ci-input/sdk archive HEAD | tar -x -C "$sdk"
cd "$sdk"
test "$(grep -c '^    version = "0.1.0-alpha01"$' build.gradle.kts)" = 1
sed 's/^    version = "0.1.0-alpha01"$/    version = "0.1.0-alpha02"/' build.gradle.kts > build.gradle.kts.s1
mv build.gradle.kts.s1 build.gradle.kts
grep -Fx 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip' gradle/wrapper/gradle-wrapper.properties
grep -Fx 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' gradle/wrapper/gradle-wrapper.properties
for role in MadSpacing MadTypography MadProvideTypography MadText; do
  module=maduikit-theme; [[ "$role" != MadText ]] || module=maduikit-components
  target="$module/src/commonMain/kotlin/com/mad/maduikit/$role.kt"
  test ! -e "$target"
  cp "$ci/overlay/$role.kt" "$target"
  shasum -a 256 "$target" >> "$out/overlay.sha256"
done
export GRADLE_USER_HOME="$work/producer-gradle"
flags=(--no-daemon --console=plain --no-build-cache -Pandroid.useAndroidX=true)
runlog publisher-help 240 bash gradlew "${flags[@]}" help
touch "$out/publisher-configured"
test ! -e "$stage"
tasks=()
for module in maduikit-theme maduikit-components; do
  for leaf in KotlinMultiplatform AndroidRelease IosArm64 IosSimulatorArm64; do
    tasks+=(":${module}:publish${leaf}PublicationToMadUIKitLocalRepository")
  done
done
runlog publish 720 bash gradlew "${flags[@]}" "-PmaduikitStagingDir=$stage" "${tasks[@]}"
gate=stage-verify
python3 "$ci/verify-stage.py" "$stage" > "$out/stage-before.json"
for entry in maduikit-theme maduikit-components; do
  adopter="$work/$entry"
  mkdir "$adopter"
  cp -R "$ci/adopter/." "$adopter/"
  cp "$sdk/gradlew" "$adopter/"; cp -R "$sdk/gradle" "$adopter/"
  cd "$adopter"
  export GRADLE_USER_HOME="$work/$entry-gradle"
  test ! -e "$GRADLE_USER_HOME"
  options=("-PmadStage=$stage" "-PmadSdkEntry=$entry" -PmadApple=true)
  runlog "$entry-help" 180 bash gradlew "${flags[@]}" "${options[@]}" help
  for target in android simulator device; do
    case "$target" in
      android) conf=debugCompileClasspath; task=compileDebugKotlinAndroid;;
      simulator) conf=iosSimulatorArm64CompileKlibraries; task=compileKotlinIosSimulatorArm64;;
      device) conf=iosArm64CompileKlibraries; task=compileKotlinIosArm64;;
    esac
    runlog "$entry-$target" 180 bash gradlew "${flags[@]}" "${options[@]}" "-PmadCompileConfiguration=$conf" ":composeApp:verifySdkCompile" ":composeApp:$task"
    cp "composeApp/build/reports/sdk-$entry-$conf.txt" "$out/"
  done
done
gate=stage-immutable
python3 "$ci/verify-stage.py" "$stage" > "$out/stage-after.json"
cmp "$out/stage-before.json" "$out/stage-after.json"
gate=verified-android-and-ios-compile-only
