# Android atomic decorative PNG: native gate PASS

[Run 44471409431](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44471409431), job135381527630, passed 2026-11-19.
Tested commit `db557bbd962412b2e6342eb59e7623c055fa420e`, isolated `ci/android-atomic`.
SDK `19c8c1b1fbe75b7d6a6118fdab42048948de091b`; Codegen `ab86297465b3cc0107be493a2ce9c1a5ece96be6`.

## Evidence chain
1. Fresh public pinned checkout, Codegen checks/distribution and external SDK Android staging passed.
2. Generic three-bars atomic fixture generated through the verified-generation wrapper. Original input/map/PNG and full bundle retained.
3. Isolated CI checkout installs generated Kotlin and PNG unchanged, adds Compose resources configuration and a white synthetic host. Its gradient-specific gate is replaced with a strict source/resource/receipt equality gate for this fixture. This is not a production consumer change or the gradient consumer test suite.
4. Real APK contains exactly one matching asset entry, byte-identical to verified PNG:
`assets/composeResources/dev.maduikit.demo.resources/drawable/mad_icon_synthetic_bars.png`.
5. APK installed/launched on Android15/API35 Google APIs x86_64 emulator, Pixel2 profile, forced density160. Native1080×1920 screenshot shows the label and deliberately small16×12 cyan bars.
6. Native generated40×24 frame region at(24,72) matches960/960 expected RGB pixels including white transparent-background composition. Decoder and APK checks rerun against downloaded artifact passed.

## Hashes
- Artifact14504666496, `public-android-atomic`, ZIP SHA256 `ce42199ca016a98cd6286ad0976c2b0532d7a9bc2df0ea4c6a6d88b86f501a9b`.
- APK `a724493a6f117f05672b9cf9b585e0e95544fff24aef578cf5c238c659518c07`.
- Generated Kotlin `556f9b3c6befc822466cedfd53c9a394ae718b71d5e535533540fe887705db59`.
- PNG `56ece1008dd2e7f99b442ed3de6f4e8d8394bb97dc6d05fbf9450a04f330b6aa`.
- External components AAR `f0daeaf2f10316b0d56493d875fb0e376a1b23821ad2765f81b6790c54a93ed5`.
- External theme AAR `c363ceb5ea428109755aed91c73a5500cd5574a5476fc945737627d07692649b`.

## Scope
This validates one approved generic PNG resource through generation, Compose typed resource packaging and native Android rendering. It does not validate private Search, general flattening, full-screen parity, other densities, iOS/Harmony resources, interactions or physical devices. No private inputs or main-branch changes.

Prior Android filter run hit upstream429 before compilation. This distinct resource gate was attempted once after an official Maven endpoint preflight returned200, with no overlapping run; it passed without retry. Android filter interaction remains separately unverified.
