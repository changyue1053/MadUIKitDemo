#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
parent=1dc3a9a1f1049aa03dd832525aad50a2f90a9d9e
sdk_pin=ba01bdf981085bfd4be9dde644a619f62ceffbe2
version=0.1.0-alpha27-sdk-preview01
test "${GITHUB_REF:-}" = refs/heads/ci/sdk-alpha27-source-composite
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
 probeClassCompiled=compiled=="yes", formClassCompiled=compiled=="yes", collectionClassCompiled=compiled=="yes", flowClassCompiled=compiled=="yes", workspaceClassCompiled=compiled=="yes",
 verifiedCalls=["MadSwitch","MadIcon","MadIconButton","MadCheckbox","MadRadio","MadDivider","MadActionButton","MadTextField","MadBadge","MadSearchField","MadListItem","MadAvatar","MadCard","MadNavigationBar","MadNavigationItem","MadLinearProgress","MadConfirmDialog","MadTopAppBar","MadStatePanel","MadBanner","MadBottomSheet","MadScaffold","MadTextArea","MadDecoratedTextField","MadSearchFieldWithClear"] if compiled=="yes" else [],
 verifiedButtonVariants=["Primary","Secondary","Text","Danger"] if compiled=="yes" else [],
 probeSourceSha256=fingerprint("source-sha"),probeClassSha256=fingerprint("class-sha"),
 formSourceSha256=fingerprint("form-source-sha"),formClassSha256=fingerprint("form-class-sha"),
 collectionSourceSha256=fingerprint("collection-source-sha"),collectionClassSha256=fingerprint("collection-class-sha"),
 flowSourceSha256=fingerprint("flow-source-sha"),flowClassSha256=fingerprint("flow-class-sha"),
 workspaceSourceSha256=fingerprint("workspace-source-sha"),workspaceClassSha256=fingerprint("workspace-class-sha"),
 verifiedWorkspaceCalls={"MadTopAppBar":1,"MadStatePanel":1,"MadBanner":1,"MadBottomSheet":1,"MadScaffold":1,"MadTextArea":1,"MadDecoratedTextField":1,"MadSearchFieldWithClear":1} if compiled=="yes" else {},
 verifiedFlowCalls={"MadNavigationBar":1,"MadNavigationItem":2,"MadLinearProgress":1,"MadConfirmDialog":1} if compiled=="yes" else {},
 verifiedCollectionCalls={"MadSearchField":1,"MadListItem":1,"MadAvatar":1,"MadCard":1} if compiled=="yes" else {},
 verifiedFormCalls={"MadTextField":4,"MadBadge":1} if compiled=="yes" else {},
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
.github/workflows/sdk-alpha27-source-composite.yml
ci/sdk-source-composite/check-workspace-calls.sh
ci/sdk-source-composite/composite/composeApp/build.gradle.kts
ci/sdk-source-composite/composite/composeApp/src/commonMain/kotlin/WorkspaceProbe.kt
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
gate=pin-shared-form
cd "$w/app"
controls_sha=205cfb76b429056d543f2c3154a923ecb3dfc91310a91fb7f61ba0a1a93eb0b1
printf '%s  %s\n' "$controls_sha" composeApp/src/commonMain/kotlin/ControlsProbe.kt | shasum -a 256 -c
trial_sha=3613c4105416edbc7e2ddff6dc9713f1fb3ed077471f1cd030b297ff1c70ad4f
trial_src=composeApp/src/commonMain/kotlin/TrialForm.kt
printf '%s  %s\n' "$trial_sha" "$trial_src" | shasum -a 256 -c
printf '%s\n' "$trial_sha" > "$w/form-source-sha"
collection_sha=253c43b47b2e91dc10bf0446f414d7efa29e63f8417813763e70f5ffdc484ca5
printf '%s  %s\n' "$collection_sha" composeApp/src/commonMain/kotlin/CollectionProbe.kt | shasum -a 256 -c
printf '%s\n' "$collection_sha" > "$w/collection-source-sha"
flow_sha=b72c297ed3a25c463820406afec07a73407e754b69b3bbb54e93458adfa67f7d
printf '%s  %s\n' "$flow_sha" composeApp/src/commonMain/kotlin/FlowProbe.kt | shasum -a 256 -c
printf '%s\n' "$flow_sha" > "$w/flow-source-sha"
workspace_sha=239460b1b9f6bec8f5729cc37b3c15e89091fcea388388425ceff37317bbec4c
printf '%s  %s\n' "$workspace_sha" composeApp/src/commonMain/kotlin/WorkspaceProbe.kt | shasum -a 256 -c
printf '%s\n' "$workspace_sha" > "$w/workspace-source-sha"
gate=resolve-and-compile-android
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
gate=check-actual-form-compile-output
class="$(find "$w/app/composeApp/build" -type f -path '*/dev/mad/synthetic/typography/TrialFormKt.class' -print)"
test -n "$class" && test -s "$class"
"$JAVA_HOME/bin/javap" -c -p "$class" > "$w/form.javap"
bash "$here/check-form-calls.sh" "$w/form.javap"
shasum -a 256 "$class" | awk '{print $1}' > "$w/form-class-sha"
gate=check-actual-collection-compile-output
class="$(find "$w/app/composeApp/build" -type f -path '*/dev/mad/synthetic/typography/CollectionProbeKt.class' -print)"
test -n "$class" && test -s "$class"
"$JAVA_HOME/bin/javap" -c -p "$class" > "$w/collection.javap"
bash "$here/check-collection-calls.sh" "$w/collection.javap"
shasum -a 256 "$class" | awk '{print $1}' > "$w/collection-class-sha"
gate=check-actual-flow-compile-output
class="$(find "$w/app/composeApp/build" -type f -path '*/dev/mad/synthetic/typography/FlowProbeKt.class' -print)"
test -n "$class" && test -s "$class"
"$JAVA_HOME/bin/javap" -c -p "$class" > "$w/flow.javap"
bash "$here/check-flow-calls.sh" "$w/flow.javap"
shasum -a 256 "$class" | awk '{print $1}' > "$w/flow-class-sha"
gate=check-actual-workspace-compile-output
class="$(find "$w/app/composeApp/build" -type f -path '*/dev/mad/synthetic/typography/WorkspaceProbeKt.class' -print)"
test -n "$class" && test -s "$class"
"$JAVA_HOME/bin/javap" -c -p "$class" > "$w/workspace.javap"
bash "$here/check-workspace-calls.sh" "$w/workspace.javap"
shasum -a 256 "$class" | awk '{print $1}' > "$w/workspace-class-sha"
compiled=yes
gate=android-source-composite-compile-passed
