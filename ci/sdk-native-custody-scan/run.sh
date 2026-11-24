#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
existing="$here/../sdk-native-preview-proof"
pin=cec44952263f528bb3775f0af63af51b4a04b621
base=d40410b6374f16bd8242deb717736119db62b6bd
version=0.1.0-alpha03-sdk-preview01
test "${GITHUB_REF:-}" = refs/heads/ci/sdk-native-custody-typed-class
[[ "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ && "${GITHUB_RUN_ID:-}" =~ ^[0-9]{1,20}$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]{1,20}$ ]]
temp="$(cd "${RUNNER_TEMP:?}" && pwd -P)"
out="$temp/mad-custody-receipt"
mkdir "$out"
work="$(mktemp -d "$temp/mad-custody-XXXXXXXX")"
gate=source-pin
finish(){
  local result=$? cleaned=deleted
  trap - EXIT
  # No payload is uploaded even if deletion fails; record blocked custody in that case.
  if ! rm -rf -- "$work" || [[ -e "$work" ]]; then cleaned=cleanup-failed; result=1; fi
  python3 - "$out/custody-result.json" "$result" "$gate" "$pin" "$version" "$cleaned" <<'PY'
import json,os,sys
from pathlib import Path
path,code,gate,pin,version,cleaned=sys.argv[1:]
p=Path(path)
doc=json.loads(p.read_text()) if p.is_file() else dict(
    run=os.environ["GITHUB_RUN_ID"],attempt=os.environ["GITHUB_RUN_ATTEMPT"],demoCommit=os.environ["GITHUB_SHA"],
    sdkCommit=pin,version=version,mavenValidation="not-run",scan="not-run",stageEquality="not-run",
    findingCounts={},refusalCodes=[],stageManifestSha256=None,transport="not-authorized-no-capsule",
    scope="fresh same-run stage scan, not original stage identity, no binary or capsule export")
doc.update(exit=int(code),gate=gate,scratchCleanup=cleaned)
if cleaned!="deleted": doc["scan"]="blocked-cleanup-failed"
p.write_text(json.dumps(doc,sort_keys=True,indent=2)+"\n")
PY
  exit "$result"
}
trap finish EXIT
# All command output except the typed receipt stays in private job scratch.
exec > "$work/local.log" 2>&1
test "$(git rev-parse HEAD^)" = "$base"
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
git diff --exit-code "$base" HEAD -- . ':!.github/workflows/sdk-native-custody-scan.yml' ':!ci/sdk-native-custody-scan/run.sh' ':!ci/sdk-native-custody-scan/job.py' ':!ci/sdk-native-custody-scan/audit.py'
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$pin"
git -C ci-input/sdk diff --quiet HEAD --
gate=host-prerequisites
test "$(uname -s)" = Darwin && test "$(uname -m)" = x86_64
test "${ImageOS:-}" = macos15
[[ "${ImageVersion:-}" =~ ^[0-9.]{5,35}$ ]]
export DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer
test -d "$DEVELOPER_DIR"
test "$(xcodebuild -version)" = "$(printf '%s\n' 'Xcode 26.0.1' 'Build version 17A400')"
test "$(xcrun --sdk iphoneos --show-sdk-version)" = 26.0
test "$(xcrun --sdk iphonesimulator --show-sdk-version)" = 26.0
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required}}"
test -f "$ANDROID_HOME/platforms/android-36/android.jar"
"${JAVA_HOME:?JDK17}/bin/java" -version 2>&1 | grep -Eq 'version "17\.'
gate=source-policy
sdk="$work/sdk"
mkdir "$sdk"
git -C ci-input/sdk archive "$pin" | tar -x -C "$sdk"
python3 "$existing/bounded.py" 30 "$work/source.log" python3 "$sdk/scripts/verify-preview-source.py"
grep -Fx 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' "$sdk/gradle/wrapper/gradle-wrapper.properties"
gate=publish-single-stage
stage="$work/stage"
export GRADLE_USER_HOME="$work/gradle-home"
tasks=()
for m in maduikit-theme maduikit-components; do
 for leaf in KotlinMultiplatform AndroidRelease IosArm64 IosSimulatorArm64; do
  tasks+=(":${m}:publish${leaf}PublicationToMadUIKitLocalRepository")
 done
done
(cd "$sdk"; python3 "$existing/bounded.py" 960 "$work/publish.log"    bash gradlew --no-daemon --console=plain --no-build-cache --max-workers=1 "-PmaduikitStagingDir=$stage" "${tasks[@]}")
gate=stage-structural-and-custody-scan
python3 "$existing/bounded.py" 250 "$work/scan.log" python3 "$here/job.py" "$work" "$out/custody-result.json"
gate=scan-completed-no-export
