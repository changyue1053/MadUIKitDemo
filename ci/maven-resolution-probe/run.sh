#!/usr/bin/env bash
set -euo pipefail
[[ $(uname -s) == Darwin && $(uname -m) == x86_64 ]]
base=4c06ed7af7062b859ab06707493dde0f9e7061bf
sdk_pin=19c8c1b1fbe75b7d6a6118fdab42048948de091b
root="$(pwd -P)"
sdk="$root/ci-input/sdk"
src="$root/ci/maven-resolution-probe/project"
out="${RUNNER_TEMP:?}/maven-resolution-evidence"
work="$(mktemp -d "$RUNNER_TEMP/mad-maven-probe.XXXXXX")"
stage="$work/maven-sdk"
mkdir -p "$out"
trap 'rm -rf -- "$work"' EXIT
test "$(git -C "$sdk" rev-parse HEAD)" = "$sdk_pin"
grep -Fx 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' "$sdk/gradle/wrapper/gradle-wrapper.properties"

git merge-base --is-ancestor "$base" HEAD
git diff --exit-code "$base" HEAD -- . ':!ci/maven-resolution-probe' ':!.github/workflows/maven-resolution-probe.yml'
[[ -z "$(find "$src" -type f \( -name '*.kt' -o -name '*.java' -o -name '*.xml' \) -print -quit)" ]]
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Missing Android SDK}}"
if [[ ! -f "$ANDROID_HOME/platforms/android-36/android.jar" || ! -d "$ANDROID_HOME/build-tools/35.0.0" ]]; then
  "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" 'platforms;android-36' 'build-tools;35.0.0'
fi
# Separate temporary Gradle home for public SDK staging; do not seed fixture implicitly.
(cd "$sdk" && GRADLE_USER_HOME="$work/sdk-home" bash gradlew --no-daemon --console=plain "-PmaduikitStagingDir=$stage" \
  :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishAndroidReleasePublicationToMadUIKitLocalRepository \
  :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-components:publishAndroidReleasePublicationToMadUIKitLocalRepository)
# Runner-local, fixture-only Gradle home. Never uploaded, cached externally, or transported off host.
export GRADLE_USER_HOME="$work/probe-home"
for mode in online offline; do
  project="$work/$mode"
  mkdir "$project"
  cp -R "$src/." "$project/"
  cp "$sdk/gradlew" "$project/"
  cp -R "$sdk/gradle" "$project/"
  flags=(--no-daemon --console=plain)
  [[ "$mode" != offline ]] || flags+=(--offline)
  (cd "$project" && bash gradlew "${flags[@]}" \
    "-PmadStage=$stage" "-PprobeMode=$mode" "-PprobeReceipt=$work/$mode.json" :app:resolvePublicAndroidRuntime)
done
cmp "$work/online.json" "$work/offline.json"
cp "$work/online.json" "$out/runtime-graph.json"
python3 - "$out" "$stage" "$sdk" "$base" "$sdk_pin" <<'PY'
import hashlib,json,platform,subprocess,sys
from pathlib import Path
out,stage,sdk=map(Path,sys.argv[1:4])
base,pin=sys.argv[4:]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
sha_manifest={str(p.relative_to(stage)):sha(p) for p in sorted(stage.rglob('*')) if p.is_file()}
assert sha_manifest and all(p.startswith('com/mad/maduikit/') for p in sha_manifest)
(out/'stage-sha256.json').write_text(json.dumps(sha_manifest,indent=2)+'\n')
(out/'summary.json').write_text(json.dumps(dict(
    baseline=base,sdkPin=pin,workflowCommit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    architecture=platform.machine(),os=platform.system(),java=subprocess.check_output(['java','-version'],stderr=subprocess.STDOUT,text=True).splitlines()[0],
    wrapperPropertiesSha256=sha(sdk/'gradle/wrapper/gradle-wrapper.properties'),runtimeGraphSha256=sha(out/'runtime-graph.json'),
    stageManifestSha256=sha(out/'stage-sha256.json'),offlineGraphMatchesOnline=True,
    probe='public no-source debugRuntimeClasspath; same runner-local dependency cache only; no compile/runtime'),indent=2)+'\n')
PY
