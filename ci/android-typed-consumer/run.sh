#!/usr/bin/env bash
set -euo pipefail
root="$PWD"; sdk="$root/ci-input/sdk"; codegen="$root/ci-input/codegen"
out="${RUNNER_TEMP:?}/android-typed-evidence"
mkdir -p "$out"
exec > >(tee "$out/build.log") 2>&1
work="$(mktemp -d "$RUNNER_TEMP/mad-typed-android.XXXXXX")"
stage="$work/versioned-maven"; consumer="$work/consumer"
test "$(git -C "$sdk" rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
test "$(git -C "$codegen" rev-parse HEAD)" = 7276d8f3843a91ec5394e527fcbd1a63ad99a712
printf 'demoProbe=%s\nsdk=%s\ncodegen=%s\n' "$(git rev-parse HEAD)" "$(git -C "$sdk" rev-parse HEAD)" "$(git -C "$codegen" rev-parse HEAD)" > "$out/pins.txt"
git diff --exit-code 8386899f3e8053b8acb0966146bc4c6142c8edee HEAD -- . ':!ci/android-typed-consumer' ':!.github/workflows/android-typed-consumer.yml'
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" 'platforms;android-36' 'build-tools;35.0.0'
(cd "$codegen" && bash gradlew --no-daemon --console=plain check installDist)
(cd "$sdk" && bash gradlew --no-daemon --console=plain \
 :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
 :maduikit-theme:publishAndroidReleasePublicationToMadUIKitLocalRepository \
 :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
 :maduikit-components:publishAndroidReleasePublicationToMadUIKitLocalRepository "-PmaduikitStagingDir=$stage")
mkdir "$consumer"
cp -R ci/android-typed-consumer/{app,scripts,settings.gradle.kts,build.gradle.kts,gradle.properties} "$consumer/"
cp "$sdk/gradlew" "$consumer/"; cp -R "$sdk/gradle" "$consumer/"
! grep -RE 'includeBuild|flatDir|mavenLocal|implementation\(files|api\(project' "$consumer" --include='*.gradle.kts'
export ORG_GRADLE_PROJECT_madStage="$stage"
export ORG_GRADLE_PROJECT_madCodegen="$codegen"
for state in enabled disabled; do
 stateOut="$out/$state"
 python3 ci/android-typed-consumer/prepare-bundle.py "$codegen" "$consumer" "$stateOut" "$state"
 (cd "$consumer" && bash gradlew --no-daemon --console=plain :app:assembleDebug)
 cp "$consumer/app/build/reports/sdk-adoption.txt" "$stateOut/"
 cp "$consumer/app/build/outputs/apk/debug/app-debug.apk" "$stateOut/typed-consumer.apk"
 (cd "$stateOut" && sha256sum typed-consumer.apk > apk.sha256)
done
! cmp -s "$out/enabled/typed-consumer.apk" "$out/disabled/typed-consumer.apk"
printf 'PASS: two verified generated Android APKs compiled with staged Maven SDK. No runtime claim.\n' > "$out/result.txt"
