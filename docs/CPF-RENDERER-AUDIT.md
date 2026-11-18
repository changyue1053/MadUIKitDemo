# CPF ARM64 target and renderer audit

## Scope

Synthetic public probe only. No production SDK/main changes, no private Figma material and no runtime acceptance. The app now uses an isolated ARM64-only build adapter, matching its SDK adapters, instead of retaining unused Android/iOS/OHOS-x64 targets from the vendor example. This fixes the probe's target contract rather than adding untested targets to the SDK adapters.

Audit code commit: `0d3c25d81179dd098b4d003671c10b5cfb50ea16` on `ci/cpf-sdk-arm64-audit`.
CI: https://github.com/changyue1053/MadUIKitDemo/actions/runs/44410732596

## Exact published renderer artifact audit

Source: https://maven.eazytec-cloud.com/nexus/repository/maven-public/org/jetbrains/compose/ui/ui-ohosarm64/1.9.2-1.2.0/ui-ohosarm64-1.9.2-1.2.0.module

Downloaded bytes match SHA-256 values recorded in the artifact's Gradle module metadata:

- UI KLIB: `c9c6a95f31ea8cbf0b9071f876ab3127eca5b6fb3f2e8979126070eacb836662`
- UI sources JAR: `287b3bda2bc4e763a83c51d3d65f6b2f77267e9f97282245f99735f775bc06d4`
- Standard Skiko sources JAR (`0.9.22.2-1.2.0`): `6de8f36c64d922b1e143a72ad504d8508c7bb63ee33495aaf6197a69664fa9e7`

The UI KLIB manifest reports compiler `2.2.21-1.2.0`, native target `ohos_arm64`, and dependencies on BOTH `org.jetbrains.skiko:skiko` and `org.jetbrains.skiko.fusion:skiko`. However, the published UI API variant metadata lists only standard `org.jetbrains.skiko:skiko:0.9.22.2-1.2.0` among its Skiko dependencies. This is a concrete publication/dependency boundary difference, not proof that adding another renderer library is safe.

## Reachability findings

The exact published `StrategyRegistrationConfig.kt` declares mode `both`, default backend ID `1` (Fusion), and registers both Fusion and Skia. `RendererBackendProvider.kt` eagerly bootstraps strategy registration. Therefore `rendererBackend=skia` is not evidence that Fusion code was excluded from the published UI binary.

Some problematic references are deferred: `FusionRendererRegistration.kt` places the Fusion font loader in `onActivated` and the `ArkTsContext.Ratio` access inside a provider lambda. These source observations explain why a link can succeed with partial-linkage diagnostics. They do NOT establish that every affected function is unreachable during native bootstrap, host lifecycle, rendering or interop. Runtime backend selection is passed through the native controller bridge, which this compile/link-only gate has not executed.

The previous SDK gate and original gradient-only gate had the same 92 distinct normalized missing/unlinked class, function and property diagnostics. They predate the SDK adaptation, but repetition does not make them harmless.

No diagnostics were suppressed; no Fusion binaries were blindly added; no upstream library sources were patched. Full native host / OHPM artifact pairing and startup/render tests remain necessary before runtime acceptance.

## CI result

PASS: run `44410732596`, job `135177843754`, completed 2026-11-18 at 22:32 UTC. Both SDK modules and the app compiled for OHOS ARM64; native linking produced an AArch64 ELF shared object with the defined `MainArkUIViewController` export.

The decoded job log no longer contains the unused-target dependency-resolution warnings (`Could not resolve`, `could not be resolved`, `No matching variant`). This is achieved by narrowing this isolated app adapter to its intended ARM64 target, NOT by proving Android, iOS or OHOS-x64 compatibility in this probe.

Output `libkn.so` SHA-256: `5c98146e58b7c79f7b83ad2bb414e021d54e069c028c80a710ed68e452961954`.
Output `libkn_api.h` SHA-256: `6f4d862261c0bc2a0c4e0675f6f06860e1ee543a835050ad727515619e83542b`.

Fusion missing-symbol diagnostics remain in the native link log. Successful linking is not startup/render verification. There is still no HAP packaging, signing, installation, interaction or device screenshot. Production SDK/main has not been modified.
