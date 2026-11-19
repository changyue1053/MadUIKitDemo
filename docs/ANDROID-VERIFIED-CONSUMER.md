# Verified generated bundle → Android consumer

## Result

[GitHub Actions run 44428611757, attempt 2](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44428611757/attempts/2)
passed on 2026-11-19. Tested Demo commit:
`31eff7c369d45b0bae47046bb62eef5995dd16aa` on the isolated
`ci/android-verified-consumer` branch. No production main source was modified
by this probe.

Inputs were fresh, credential-free public checkouts:

- SDK: `19c8c1b1fbe75b7d6a6118fdab42048948de091b`.
- Codegen: `9ac33f74fcbe51067f6b7de544043f97591e7ec1`.
- JDK 17, Android compile SDK 36, Build Tools 35.0.0.
- Runtime: Android 15 / API 35 Google APIs x86_64 emulator, Pixel 2 profile.

## Verified gates

1. Codegen `check installDist` passed, including its nine prior suites and 22
   verified-generation safety checks.
2. SDK theme unit test and filesystem-only Android/KMP staging completed.
3. Demo fresh-bundle gate and ten consumer rejection/acceptance checks passed.
4. Resolved external Android AAR coordinates, versions and hashes matched the
   newly staged SDK; no source or composite-build substitution was used.
5. Android Kotlin compiled and debug APK assembled.
6. That APK was installed and launched on the API 35 emulator. Activity launch
   returned `Status: ok`, the expected app was foreground, and the native UI
   tree contained the synthetic `MadUIKit` page text.
7. Captured and visually inspected the native 1080×1920 PNG. The synthetic
   Chinese text and both gradients are visible. No fatal exception appeared
   in the captured post-launch log.

This confirms the mandatory Codegen prerequisite can be provisioned from a
fresh checkout rather than bypassed with stale generated output.

## Artifact integrity

Successful artifact ID: `14486940267`, named
`public-android-verified-consumer`. Earlier failed attempts also have artifacts;
use this ID for the successful evidence.

- Artifact ZIP SHA-256:
  `38e41a30aca59653fd2357baffc73218c76586cd9e0f2fcfd7e88d59ceefe911`.
- Installed APK SHA-256:
  `d88f6805180bc25958d7d2d3fbf73529adf14b8d339237bb19f93f1de68efe64`.
- Components Android AAR SHA-256:
  `f0daeaf2f10316b0d56493d875fb0e376a1b23821ad2765f81b6790c54a93ed5`.
- Theme Android AAR SHA-256:
  `c363ceb5ea428109755aed91c73a5500cd5574a5476fc945737627d07692649b`.

The artifact contains build/runtime logs, commit pins, APK/checksum, UI XML,
activity evidence and `Android-Verified-Consumer.png`. Retention is seven days;
it is test evidence, not a release distribution. No private Figma material or
credentials were used or uploaded.

## Corrected harness and retained limits

The first run built the APK but failed before app installation because the AVD
manager and emulator selected different default directories. The corrected
script declares explicit shared Android/AVD directories, asserts the named AVD
exists, and detects an exited emulator before waiting for it. A subsequent
attempt hit an upstream Maven dependency lookup failure; the unchanged pinned
job passed on retry.

This is **launch and visual-presence validation of the synthetic page**, not
private-design pixel parity, interaction coverage, accessibility acceptance,
physical-device testing, a signed release, or iOS/Harmony runtime validation.
System-bar appearance is visible in the capture but has not been accepted as a
polished design. The generated gradient page does not exercise `MadFilterTabs`;
SDK binary inclusion alone is not that component's runtime test.

The workflow provisions its pinned prerequisites explicitly. Local builds still
require the SDK filesystem stage and a built compatible Codegen checkout as
specified in the main README. Existing unrelated workflows were not changed.
