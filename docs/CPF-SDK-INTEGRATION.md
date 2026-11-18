# CPF SDK module integration gate

## Scope

Public synthetic test only. No private Figma nodes, assets, generated source or screenshots are present. This gate exercises actual MadTheme, MadFilterTabs and MadFilterTab implementations, plus the existing public gradient page. It does not test runtime behavior.

## Version matrix

| Item | Pin |
| --- | --- |
| SDK common sources | MadUIKit 19c8c1b1fbe75b7d6a6118fdab42048948de091b |
| Public gradient | MadUIKitCodegen b174b847a6e4096924bb1026d1b94a8d9a0c49a8 |
| CPF upstream example | a049930ec7d874f292427288d5389acf4f98ed3b |
| CPF Kotlin / Compose compiler | 2.2.21-1.2.0 |
| CPF Compose plugin / OHPM bridge | 1.9.2-1.2.0 |
| Backend / Skiko | Skia / 0.9.22.2-1.2.0 |
| Gradle / JDK / runner | 8.9 / 17 / ubuntu-24.04 x64 |

SDK main currently uses Kotlin 2.2.21, Compose 1.9.3, Material3 1.9.0 and AGP 8.11.1, with Android/iOS targets and no OHOS target. The pinned CPF example instead uses its own plugin and artifact set. Do not mix these catalogs or claim the unmodified SDK build is Harmony-ready.

## Dependency boundary

The adapter stages exact hash-verified SDK common sources in separate `:maduikit-theme` and `:maduikit-components` Gradle projects. The application depends on components, which exposes a project dependency on theme. Each module is compiled to its own OHOS ARM64 KLIB. The app invokes MadTheme and MadFilterTabs directly. No SDK sources are copied into the app compilation.

These are real project dependencies within an isolated CPF build, but the module build scripts are purpose-built CPF adapters. This is NOT verification of the SDK's original Gradle modules, published Maven artifacts, publication metadata, consumer resolution, or cross-toolchain binary compatibility.

## Local checks

- Python syntax and shell syntax passed.
- Staging with exact pinned upstream and SDK source hashes passed.
- Modified SDK common source rejected before staging.
- Separate project dependency chain and OHOS target declarations verified.

## CI evidence

Commit: 5bdbfba078dcd6419ca325d32a10def738d33e8f
Run: https://github.com/changyue1053/MadUIKitDemo/actions/runs/44400054652

## Verified native outcome

Run 44400054652 completed successfully on 2026-11-18 at approximately 21:33 UTC.

- `:maduikit-theme:compileKotlinOhosArm64`, `:maduikit-components:compileKotlinOhosArm64`, and `:composeApp:compileKotlinOhosArm64` executed successfully.
- All three KLIB manifests checked `native_targets=ohos_arm64` and `compiler_version=2.2.21-1.2.0`.
- SDK KLIB IR contains `MadTheme` and `MadFilterTabs` respectively.
- Target compile dependency report contains both project dependencies.
- `:composeApp:linkDebugSharedOhosArm64` succeeded offline.
- `readelf` verified an AArch64 DYN shared object and a defined `MainArkUIViewController` export. Generated header also contains the controller API.
- `libkn.so` SHA-256: `7a1a173c1ebc1a33f516a730b31359e558dc18b8014987d396c328b25666f7f8`.
- `libkn_api.h` SHA-256: `6f4d862261c0bc2a0c4e0675f6f06860e1ee543a835050ad727515619e83542b`.

## Limitations and warnings

This is a successful ARM64 project-adapter compile/link gate, not a clean all-platform build. The upstream app still declares Android, iOS and OHOS x64, while the isolated SDK adapters declare only OHOS ARM64, so Gradle warns that the project dependency cannot resolve for all source-set platforms. The exact ARM64 configuration resolves and compiles successfully. Other targets were not tested by this probe.

The successful link also emits upstream Compose FusionRenderer partial-linkage diagnostics for missing `ExternalRenderNode`, `ArkTsContext` and related symbols under the pinned Skia backend. These diagnostics were not suppressed. Their runtime reachability is unverified and must be resolved or demonstrated harmless before runtime acceptance. Do not interpret ELF creation or a green CI run as runtime readiness.

No HAP, signing, install, controller rendering, tap semantics, accessibility or pixel fidelity has been verified. No native runtime screenshot exists for this gate. Original SDK target wiring and Maven publication/consumer validation remain separate work. Public CI logs are the evidence; the binary was not uploaded as a release artifact.
