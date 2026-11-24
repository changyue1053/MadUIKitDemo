#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
pin=cec44952263f528bb3775f0af63af51b4a04b621
version=0.1.0-alpha03-sdk-preview01
sdk_repo="$(cd "${1:?supply SDK Git checkout}" && pwd -P)"
out="$(cd "${2:?supply unique empty receipt directory}" && pwd -P)"
test -z "$(ls -A "$out")"
demo_base=8f386c28d1b5709f3ce57adae2912993c1f8222f
demo="$(cd "$here/../.." && pwd -P)"
test "$(git -C "$demo" rev-parse HEAD^)" = "$demo_base"
git -C "$demo" diff --exit-code "$demo_base" HEAD -- . ':!.github/workflows/sdk-native-preview-proof.yml' ':!ci/sdk-native-preview-proof' > /dev/null
test "${GITHUB_REF:-}" = refs/heads/ci/sdk-native-preview-proof
test "$(git -C "$demo" rev-parse HEAD)" = "${GITHUB_SHA:?}"
[[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]]

gate=source-pin
finish(){
 local result="${1:-$?}"
 trap - EXIT
 python3 - "$out/outcome.json" "$result" "$gate" "$pin" "$version" <<'PY'
import json,os,sys
from pathlib import Path
path,code,gate,commit,version=sys.argv[1:]
Path(path).write_text(json.dumps(dict(exit=int(code),gate=gate,commit=commit,version=version,
 run=os.environ["GITHUB_RUN_ID"],attempt=os.environ["GITHUB_RUN_ATTEMPT"],demo=os.environ["GITHUB_SHA"],
 scope="Source-native synthetic Maven stage and two independent consumer compile arms only; no binary retention, link, launch or runtime."),
 indent=2)+"\n")
PY
 exit "$result"
}
trap finish EXIT
test "$(git -C "$sdk_repo" rev-parse HEAD)" = "$pin"
git -C "$sdk_repo" diff --quiet HEAD
git -C "$sdk_repo" diff --cached --quiet
git -C "$sdk_repo" rev-parse 'HEAD^{tree}' > "$out/sdk-tree.txt"
gate=host-prerequisites
test "$(uname -s)" = Darwin && test "$(uname -m)" = x86_64
test "${ImageOS:-}" = macos15
[[ "${ImageVersion:-}" =~ ^[0-9.]{5,35}$ ]]
printf 'host=Darwin-x86_64\nimage=%s\n' "$ImageVersion" > "$out/runner.txt"
export DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required}}"
: "${ANDROID_HOME:?Stock Android SDK 36 required}"
test -f "$ANDROID_HOME/platforms/android-36/android.jar"
test -x "${JAVA_HOME:?Pinned JDK17 required}/bin/java"
"$JAVA_HOME/bin/java" -version 2>&1 | grep -Eq 'version "17\.'
# Retain only fixed SDK/tool version strings, not raw path-bearing output.
test "$(xcodebuild -version)" = "$(printf '%s\n' 'Xcode 26.0.1' 'Build version 17A400')"
printf '%s\n' 'Xcode 26.0.1' 'Build version 17A400' > "$out/xcode.txt"
for apple in iphoneos iphonesimulator; do
 value="$(xcrun --sdk "$apple" --show-sdk-version)"
 test "$value" = 26.0
 printf '%s=%s\n' "$apple" "$value"
done > "$out/apple-sdks.txt"
work="$(mktemp -d "${TMPDIR:-/tmp}/mad-sdk-native-proof.XXXXXX")"
cleanup(){ local rc=$?; rm -rf -- "$work" || true; finish "$rc"; }
trap cleanup EXIT
sdk="$work/sdk"
stage="$work/stage"
mkdir "$sdk"
gate=source-review-check
git -C "$sdk_repo" archive "$pin" | tar -x -C "$sdk"
runlog(){ local seconds="$1"; shift; python3 "$here/bounded.py" "$seconds" "$work/$gate.raw.log" "$@" > "$work/$gate.status.log" 2>&1; }
runlog 30 python3 "$sdk/scripts/verify-preview-source.py"
grep -Fx 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' "$sdk/gradle/wrapper/gradle-wrapper.properties"
flags=(--no-daemon --console=plain --no-build-cache --max-workers=1)
tasks=()
for m in maduikit-theme maduikit-components; do
 for leaf in KotlinMultiplatform AndroidRelease IosArm64 IosSimulatorArm64; do
  tasks+=(":${m}:publish${leaf}PublicationToMadUIKitLocalRepository")
 done
done
gate=publish-one-isolated-stage
(
 cd "$sdk"
 export GRADLE_USER_HOME="$work/publisher-gradle"
 runlog 960 bash gradlew "${flags[@]}" "-PmaduikitStagingDir=$stage" "${tasks[@]}"
)
gate=verify-initial-stage
python3 "$here/verify-stage.py" "$stage" > "$out/stage-before.json"
confs=(debugCompileClasspath iosSimulatorArm64CompileKlibraries iosArm64CompileKlibraries)
compiles=(compileDebugKotlinAndroid compileKotlinIosSimulatorArm64 compileKotlinIosArm64)
for root in maduikit-theme maduikit-components; do
 gate="$root-fixture"
 project="$work/consumer-$root"
 cp -R "$here/adopter" "$project"
 cp "$sdk/gradlew" "$project/"
 cp -R "$sdk/gradle" "$project/"
 for i in 0 1 2; do
  conf="${confs[i]}"
  gate="$root-$conf"
  report="composeApp/build/reports/sdk-$root-$conf.txt"
  (
   cd "$project"
   export GRADLE_USER_HOME="$work/gradle-$root"
   runlog 300 bash gradlew "${flags[@]}" -Pandroid.useAndroidX=true -PmadApple=true \
      "-PmadStage=$stage" "-PmadSdkEntry=$root" "-PmadCompileConfiguration=$conf" \
      :composeApp:verifySdkCompile ":composeApp:${compiles[i]}"
  )
  python3 "$here/verify-arm.py" "$project/$report" "$out/stage-before.json" "$root" "$conf" > "$out/$gate.json"
 done
done
gate=verify-unchanged-stage
python3 "$here/verify-stage.py" "$stage" > "$out/stage-after.json"
cmp "$out/stage-before.json" "$out/stage-after.json"
gate=all-six-compile-arms-verified
