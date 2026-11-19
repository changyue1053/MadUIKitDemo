# Independent Android Maven SDK adoption: PASS

[Run44501888923](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44501888923), job135483500089, passed2026-11-19 10:05 UTC.
Tested isolated branch `ci/sdk-adoption`, commit `8386899f3e8053b8acb0966146bc4c6142c8edee`.
SDK pin `19c8c1b1fbe75b7d6a6118fdab42048948de091b`.

## Independent consumer
A new minimal native Android Books app is copied into a fresh temporary root outside both repositories. It declares exactly one direct SDK dependency:
`com.mad.maduikit:maduikit-components:0.1.0-alpha01`.
It also declares Activity Compose for its Android host, but no direct theme or individual Compose UI/Foundation dependency. Its Kotlin uses MadTheme, MadFilterTabs, MadFilterTab and BasicText, and successfully compiles/assembles a debug APK.

SDK root metadata and Android publications are freshly staged to a filesystem Maven repository. Consumer uses exclusive group routing and Gradle/POM metadata. There is no includeBuild, project dependency, SDK source copy, flatDir, manually imported loose AAR, Maven Local or Codegen prerequisite. Only standard Gradle wrapper tooling is copied from the SDK checkout.

## Actual resolved graph
- components root -> components-android
- components-android -> theme root
- theme root -> theme-android
- Compose runtime/UI/Foundation/Material3 and Kotlin dependencies propagate transitively.

Both SDK artifacts resolved as AAR, androidJvm, android environment, java-runtime variants; version0.1.0-alpha01 and artifact bytes matched the fresh Maven stage:
- components SHA256 `f0daeaf2f10316b0d56493d875fb0e376a1b23821ad2765f81b6790c54a93ed5`
- theme SHA256 `c363ceb5ea428109755aed91c73a5500cd5574a5476fc945737627d07692649b`

## Evidence and limits
Artifact14517826965 `public-independent-sdk-adoption` retains full versioned Maven stage, resolved variant/edge report, build log and APK.
ZIP SHA256 `b7682bcad1e24aa88d10b7c17584fb92dd1add41bd68f0cae8d61364c4a81c02`.
APK SHA256 `0d6742b2b563879ddc59c1562ddf0a9745b8b74620b5bc730db86ef4ba326712`.
Downloaded evidence hashes independently verified.

This is second-app **dependency/variant/transitive API compilation and packaging validation**, not an installation, runtime screenshot, signed release or remote registry publication. Only Android was tested, not second-app iOS/Harmony adoption. No private design inputs, production main edits or personal computer used. No screenshot is claimed for a compile-only stage.
