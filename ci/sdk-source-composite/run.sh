#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
parent=25608df4d1f2e783645c1429e735a90fd8df86c0
sdk_pin=532903a137952b81fa6ee773eff87c6cb39f5b86
version=0.1.0-alpha10-sdk-preview01
test "${GITHUB_REF:-}" = refs/heads/ci/sdk-alpha10-source-composite
[[ "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ && "${GITHUB_RUN_ID:-}" =~ ^[0-9]{1,20}$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]{1,20}$ ]]
tmp="$(cd "${RUNNER_TEMP:?}" && pwd -P)"
out="$tmp/mad-source-composite-receipt"
mkdir "$out"
w="$(mktemp -d "$tmp/mad-source-composite-XXXXXXXX")"
gate=pin-and-scope
root_verified=no
compiled=no
finish(){
  local rc=$? cleaned=deleted
  trap - EXIT
  python3 - "$w" "$out/composite-status.json" "$rc" "$gate" "$sdk_pin" "$version" "$root_verified" "$compiled" <<'PY'
from pathlib import Path
import json,os,sys
w,p,code,gate,sdk,ver,root,compiled=sys.argv[1:]
w,p=Path(w),Path(p)
known_stock={"host-profile","runner-image","stock-toolcache-missing","stock-jdk17-missing",
             "stock-jdk17-check-failed","stock-jdk17-version","stock-sdk36-missing","passed"}
known_cause={"passed","bounded-timeout","process-terminated","causal-block-not-observed","bounded-log-window",
             "dependency-transport","dependency-or-plugin-resolution","jdk-sdk-or-toolchain",
             "local-filesystem-or-resource","compilation","publication","compile-task-error-unclassified","first-cause-unclassified"}
def category(file, key, vocabulary):
    try:
        path=w/file
        if path.stat().st_size>1024:return "unclassified"
        value=json.loads(path.read_text())[key] if key else path.read_text().strip()
        return value if isinstance(value,str) and value in vocabulary else "unclassified"
    except FileNotFoundError:return "not-run"
    except (OSError,ValueError,KeyError):return "unclassified"
def fingerprint(name):
    try:
        value=(w/name).read_text().strip()
        return value if len(value)==64 and all(c in "0123456789abcdef" for c in value) else None
    except OSError:return None
r=dict(run=os.environ["GITHUB_RUN_ID"],attempt=os.environ["GITHUB_RUN_ATTEMPT"],demoCommit=os.environ["GITHUB_SHA"],
 sdkCommit=sdk,version=ver,exit=int(code),gate=gate,
 stockStatus=category("stock-status.txt",None,known_stock),
 gradleFailureCategory=category("gradle-category.json","publisherCategory",known_cause),
 selectedSourceRoots=["maduikit-components","maduikit-theme"] if root=="yes" else [],
 probeClassCompiled=compiled=="yes",
 verifiedCalls=["MadSwitch","MadIcon","MadIconButton","MadCheckbox","MadRadio","MadDivider","MadActionButton"] if compiled=="yes" else [],
 verifiedButtonVariants=["Primary","Secondary","Text","Danger"] if compiled=="yes" else [],
 probeSourceSha256=fingerprint("source-sha"),probeClassSha256=fingerprint("class-sha"),
 scope="synthetic Android source-composite compile only; no Maven publication, native link or execution")
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  local result="$rc"
  if ! rm -rf -- "$w" || [[ -e "$w" ]]; then
    python3 - "$out/composite-status.json" <<'PYCLEAN'
from pathlib import Path
import json,sys
p=Path(sys.argv[1]);r=json.loads(p.read_text())
r.update(exit=1,gate="scratch-cleanup-failed")
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PYCLEAN
    result=1
  fi
  exit "$result"
}
trap finish EXIT
exec > "$w/private.log" 2>&1
test "$(git rev-parse HEAD^)" = "$parent"
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
changed="$(git diff --name-only "$parent" HEAD | LC_ALL=C sort)"
expected="$(cat <<'FILES'
.github/workflows/sdk-alpha10-source-composite.yml
ci/sdk-source-composite/check-calls.sh
ci/sdk-source-composite/composite/composeApp/build.gradle.kts
ci/sdk-source-composite/composite/composeApp/src/commonMain/kotlin/ControlsProbe.kt
ci/sdk-source-composite/composite/settings.gradle.kts
ci/sdk-source-composite/run.sh
FILES
)"
test "$changed" = "$expected"
test "$(git -C ci-input/sdk rev-parse HEAD)" = "$sdk_pin"
gate=stock-tools
python3 "$here/stock-env.py" "$w"
JAVA_HOME="$(sed -n '1p' "$w/private-toolpaths.txt")"
ANDROID_HOME="$(sed -n '2p' "$w/private-toolpaths.txt")"
export JAVA_HOME ANDROID_HOME
gate=verify-source
mkdir "$w/sdk"
git -C ci-input/sdk archive "$sdk_pin" | tar -x -C "$w/sdk"
python3 "$w/sdk/scripts/verify-preview-source.py"
grep -Fx 'distributionSha256Sum=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78' "$w/sdk/gradle/wrapper/gradle-wrapper.properties"
cp -R "$here/composite" "$w/app"
cp "$w/sdk/gradlew" "$w/app/"
cp -R "$w/sdk/gradle" "$w/app/"
gate=resolve-and-compile-android
cd "$w/app"
export GRADLE_USER_HOME="$w/gradle"
set +e
python3 "$here/bounded.py" 480 "$w/gradle.log" bash gradlew --no-daemon --console=plain --no-build-cache --max-workers=1 \
   "-PmadSdkSource=$w/sdk" -Pandroid.useAndroidX=true \
   :composeApp:verifySourceComposite :composeApp:compileDebugKotlinAndroid
rc=$?
set -e
if [[ "$rc" != 0 ]]; then
 python3 "$here/first-cause.py" "$rc" "$w/gradle.log" > "$w/gradle-category.json"
 exit "$rc"
fi
gate=check-source-root-receipt
grep -Fxq SOURCE_COMPOSITE_ROOTS_VERIFIED "$w/gradle.log"
root_verified=yes
gate=check-actual-compile-output
grep -Fxq '> Task :composeApp:compileDebugKotlinAndroid' "$w/gradle.log"
class="$(find "$w/app/composeApp/build" -type f -path '*/dev/mad/synthetic/typography/ControlsProbeKt.class' -print)"
test -n "$class" && test -s "$class"
"$JAVA_HOME/bin/javap" -c -p "$class" > "$w/probe.javap"
bash "$here/check-calls.sh" "$w/probe.javap"
shasum -a 256 "$class" | awk '{print $1}' > "$w/class-sha"
shasum -a 256 composeApp/src/commonMain/kotlin/ControlsProbe.kt | awk '{print $1}' > "$w/source-sha"
compiled=yes
gate=android-source-composite-compile-passed
