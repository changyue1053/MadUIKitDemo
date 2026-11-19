#!/usr/bin/env bash
set -euo pipefail
root="$(pwd)"
evidence="$root/ci-evidence/android-filter"
mkdir -p "$evidence"
exec > >(tee "$evidence/build.log") 2>&1
sdk="$root/ci-input/MadUIKit"
codegen="$root/ci-input/MadUIKitCodegen"
stage="$root/ci-stage/maduikit-maven"
test "$(git -C "$sdk" rev-parse HEAD)" = 19c8c1b1fbe75b7d6a6118fdab42048948de091b
test "$(git -C "$codegen" rev-parse HEAD)" = ab86297465b3cc0107be493a2ce9c1a5ece96be6
printf 'Demo commit: %s\nSDK commit: %s\nCodegen commit: %s\n' "$(git rev-parse HEAD)" "$(git -C "$sdk" rev-parse HEAD)" "$(git -C "$codegen" rev-parse HEAD)" | tee "$evidence/commits.txt"
: "${ANDROID_HOME:?Hosted runner Android SDK required}"
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" 'platforms;android-36' 'build-tools;35.0.0' 'platform-tools'
(cd "$codegen" && bash gradlew --no-daemon check installDist)
(cd "$sdk" && bash gradlew --no-daemon \
  :maduikit-theme:testDebugUnitTest \
  :maduikit-theme:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-theme:publishAndroidReleasePublicationToMadUIKitLocalRepository \
  :maduikit-components:publishKotlinMultiplatformPublicationToMadUIKitLocalRepository \
  :maduikit-components:publishAndroidReleasePublicationToMadUIKitLocalRepository \
  "-PmaduikitStagingDir=$stage")
cp ci/android-filter/DemoScreen.kt composeApp/src/commonMain/kotlin/dev/maduikit/demo/DemoScreen.kt
bash gradlew --no-daemon :composeApp:verifyGeneratedSource :composeApp:consumerSmokeTest \
  :composeApp:verifyStagedAndroidSdk :composeApp:assembleDebug \
  "-PmaduikitStagingDir=$stage" "-PmaduikitCodegenDir=$codegen"
cp composeApp/build/outputs/apk/debug/composeApp-debug.apk "$evidence/public-synthetic-demo.apk"
sha256sum "$evidence/public-synthetic-demo.apk" > "$evidence/apk.sha256"
printf 'Android APK build and external SDK verification passed. Runtime not yet verified.\n'

python3 "$codegen/scripts/generate-verified.py" --launcher "$codegen/build/install/MadUIKitCodegen/bin/MadUIKitCodegen" --input "$codegen/fixtures/figma/gradient.file-nodes.json" --node 3:1 --fit-width --out "$evidence/bundle"
python3 scripts/check-structure.py --generated-source "$evidence/bundle/FigmaProfileScreen.generated.kt"
