# MadUIKitDemo

Independent Kotlin/Compose sample host for MadUIKit. Its checked-in page was
generated from the hand-authored synthetic gradient fixture in
`MadUIKitCodegen`, not an actual design, screenshot or real account. The
page uses `MadTheme` from the staged SDK. Neither the Android App nor the
generator requires a live Figma connection. The sample does not submit data.

## Prepare the dependency

Check out `MadUIKit` and `MadUIKitDemo` under the same parent directory.
From the SDK checkout follow its README **Stage the Android SDK for the demo**
instructions to publish the KMP root metadata and Android release AARs locally.
The default path from both checkouts is the sibling `../maduikit-maven`.
If those checkouts do not share a parent, pass the same
`-PmaduikitStagingDir=/absolute/path/to/maduikit-maven` to both Gradle commands.
No source substitution or `mavenLocal()` is used.

Use JDK 17, Android SDK Platform 36, Build Tools 35.0.0 and Platform-Tools.
Set `JAVA_HOME` and `ANDROID_HOME` (or write the Android SDK location
to untracked `local.properties`). The Gradle Wrapper pins 8.13. With a fresh
cache allow the Gradle distribution, Gradle Plugin Portal, Google Maven and
Maven Central.

## Build and run Android

From this repository:

```sh
./gradlew :composeApp:verifyStagedAndroidSdk :composeApp:assembleDebug
adb install -r composeApp/build/outputs/apk/debug/composeApp-debug.apk
adb shell am start -n dev.maduikit.demo.p5/dev.maduikit.demo.MainActivity
```

The verification task checks the two resolved Android AAR module coordinates,
fixed version and SHA-256 against the local Maven stage. App startup displays
axis-aligned gradients and explicit fit-width behavior from the synthetic
fixture. Building the APK and viewing it are separate checks. The synthetic
sample was exercised on Android API 28, not against real design reference
pixels. The project declares iOS ARM64 targets and retains the host shell, but
the documented Android stage has no iOS binaries; that shell is outside this
rehearsal. No HarmonyOS implementation is included here.

## Verified generated-source consumer gate

Prepare a sibling `MadUIKitCodegen` checkout at commit `9ac33f7` or a compatible
later version, then run `./gradlew check installDist` there. Demo Kotlin
compilation now depends on `verifyGeneratedSource`: it generates a fresh public
synthetic gradient bundle through Codegen's verified wrapper, requires successful
receipts, and compares the checked-in Demo source byte-for-byte. A generation
failure or source mismatch stops compilation instead of accepting stale output.
Use `-PmaduikitCodegenDir=/absolute/path/to/MadUIKitCodegen` for another location.
This adds an intentional local checkout/build prerequisite; no online Figma
access or private inputs are used.

```sh
./gradlew :composeApp:verifyGeneratedSource :composeApp:consumerSmokeTest
```

The smoke test accepts the valid bundle and rejects omitted source, missing
manifest/diagnostics/source, changed code, failed diagnostics, mismatched hashes
and malformed metadata, including with Python's optimization enabled. `check`
depends on this test. These receipts are consistency checks, not cryptographic
signatures or proof of visual equivalence. Use trusted checkouts and unique
output directories as documented by Codegen.

## Inspect generated source directly

After checking out `MadUIKitCodegen` next to this repository:

```sh
python3 scripts/check-structure.py \
  --generated-source ../MadUIKitCodegen/sample-gradient-output/FigmaProfileScreen.generated.kt
sh -n scripts/ios-framework.sh
```

The Python check requires the generated file, manifest and successful diagnostics,
compares source byte-for-byte, verifies its manifest hash and checks host structure. To regenerate the fixture,
follow the Codegen README's gradient and fit-width example.


## Optional native Desktop consumer evidence

`ci/verified-consumer-desktop` is an isolated JVM verification harness. It compiles
and renders the actual checked-in `DemoScreen` and generated page, after the same
fresh-bundle gate. It compiles SDK `MadTheme` from source through an adapter;
it does **not** prove a published Desktop SDK artifact, Android/iOS/Harmony
packaging, device behavior or Figma pixel parity.

```sh
cd ci/verified-consumer-desktop
# Use the repository Gradle Wrapper with this directory as the working directory.
../../gradlew run --args=/absolute/path/to/demo-consumer.png
```

Default SDK and Codegen locations are sibling checkouts of this Demo repository.
Override with `-PmaduikitSdkDir=...` and `-PmaduikitCodegenDir=...` when needed.
The output is a genuine 390×560 native Compose Desktop capture of synthetic data,
not a device screenshot. No screenshot is checked into this repository.
