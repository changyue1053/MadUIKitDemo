# Independent iOS ARM64 device framework adoption

## Result: compile/link PASS, no device execution

[Run 44530387629](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44530387629), job 135581811159, tested commit `d9e0725282bca7ca01ac3a9d060a8ab000117cf1`, standard `macos-15-intel`, Xcode 26.0.1. Completed 2026-11-19. One bounded run only.

The [Kotlin host support table](https://kotlinlang.org/docs/native-target-support.html) permits Intel macOS hosts to produce supported Apple binaries. This test demonstrates that route with the actual project rather than requiring an ARM runner.

- SDK pinned `19c8c1b1fbe75b7d6a6118fdab42048948de091b`; all 20 tracked checkout files verified byte-identical after build. No iosX64 adapter or upstream build/source edits.
- Existing `iosArm64` SDK publications staged to filesystem Maven, including full Gradle module metadata/POM and transitive theme.
- Separate fresh Gradle root declares only `com.mad.maduikit:maduikit-components:0.1.0-alpha01` as its direct SDK dependency. No sibling project/source substitution, loose KLIB import or direct theme declaration.
- Resolution verified components root → components-iosarm64 → theme root → theme-iosarm64, `native/ios_arm64` variant, versions and staged KLIB SHA equality.
- Synthetic consumer calls MadTheme, MadFilterTabs/MadFilterTab and returns a ComposeUIViewController. Independent `linkDebugFrameworkIosArm64` succeeded.
- Framework architecture is `arm64`; Mach-O `LC_BUILD_VERSION platform 2` verifies device iOS rather than simulator. Four retained framework files match receipt SHA checks.

Timings: SDK staging 347.18 s, resolution 25.54 s, framework link 353.14 s. All bounded stages passed.

## Retained provenance

Artifact `14535021306`, `public-ios-arm64-adoption`, ZIP SHA-256:
`421aaa259159d89b4f7e6b55ac52187de1a0869b483e1e92577b313c5dd44122`.

Framework binary SHA-256:
`e83516160c811af9106436eff1a3a4580e724c9002d1f094ffa55753088c3e59`.

Components KLIB: `18f8e22bf3bbac5cdfbee18e75ca2fa976419c2076b41eaee86c94bd0c1ef284`.
Theme KLIB: `d9c6ada1ddcb820498cd8364d78ff82250015428eedc202daf0ae3b474545a1b`.

Artifact retains framework, complete versioned Maven stage, load commands, resolution report, stage logs/status and receipt. GitHub artifact retention is seven days; evidence also retained privately.

## Boundaries

Compile/link only. No iOS app packaging, signing/provisioning, installation, physical-device execution, ARM64 simulator run, release validation, performance/accessibility acceptance or screenshot. No remote registry release, personal computer, private design input, account/security change or production branch edit. Successful Intel simulator runtime remains a separate gate; this does not turn simulator evidence into device evidence.
