#!/usr/bin/env bash
set -euo pipefail
root="$PWD"; sdk="$root/ci-input/sdk"; out="$root/ci-evidence/sdk-adoption"
mkdir -p "$out"
exec > >(tee "$out/build.log") 2>&1
work="$(mktemp -d "$RUNNER_TEMP/mad-adoption.XXXXXX")"; stage="$work/versioned-maven"; consumer="$work/independent-books"
test "$(git -C "$sdk" rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" 'platforms;android-36' 'build-tools;35.0.0'
(cd "$sdk" && bash gradlew --no-daemon :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository :maduikit-theme:publishAndroidReleasePublicationToMadUIKitLocalRepository :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository :maduikit-components:publishAndroidReleasePublicationToMadUIKitLocalRepository "-PmaduikitStagingDir=$stage")
mkdir "$consumer"; cp -R ci/sdk-adoption/{app,settings.gradle.kts,build.gradle.kts,gradle.properties} "$consumer/"
cp "$sdk/gradlew" "$consumer/"; cp -R "$sdk/gradle" "$consumer/"
# New build root outside both repositories, one SDK coordinate, no source/flatDir/includeBuild.
! grep -RE 'includeBuild|flatDir|mavenLocal|implementation\(files|api\(project' "$consumer" --include='*.gradle.kts'
(cd "$consumer" && bash gradlew --no-daemon :app:assembleDebug "-PmadStage=$stage")
cp "$consumer/app/build/reports/sdk-adoption.txt" "$out/"
cp "$consumer/app/build/outputs/apk/debug/app-debug.apk" "$out/independent-books.apk"
(cd "$out" && sha256sum independent-books.apk > apk.sha256)
cp -R "$stage" "$out/versioned-maven"
printf 'PASS: independent Android app compiled with only versioned components coordinate; transitive theme and Android variants verified. No runtime/release claim.\n' > "$out/result.txt"
