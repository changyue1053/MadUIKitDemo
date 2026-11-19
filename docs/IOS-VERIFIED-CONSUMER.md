# iOS verified-consumer Intel simulator evidence

Status: **PASS**, 2026-11-19 UTC. This isolated probe validates the public synthetic CMP page, not private design parity or production ARM64.

## Reproducible inputs

- [Successful Actions run 44431911666](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44431911666), job 135251108931.
- Probe commit: `fd461bf64753d6d3d433ecd1de376f3d05b38c80`, branch `ci/ios-verified-consumer-intel`.
- Demo: `8f386c28d1b5709f3ce57adae2912993c1f8222f`.
- SDK: `19c8c1b1fbe75b7d6a6118fdab42048948de091b`.
- Codegen: `4c12c7b6e9998b7d832b766409c321bbaa12903b`.
- Standard GitHub-hosted `macos-15-intel`, Xcode 26.0.1 (17A400), SDK 26.0, installed iOS 26.0 simulator runtime. No paid runner or downloaded runtime.

The probe creates fresh pinned source archives and temporarily adds iosX64 build targets. It asserts every product Kotlin source remains byte-identical. This is a build-only compatibility adapter, not a claim that SDK main already publishes iosX64.

## Verified chain

1. Codegen aggregate check and distribution passed on macOS, including 24 verified-generation safety cases.
2. Demo regenerated a fresh public synthetic bundle, verified manifest, successful diagnostics and hashes, and compared checked-in Kotlin exactly.
3. Ten consumer checks passed, including missing/tampered rejection and Python optimization coverage.
4. Actual external SDK KLIBs resolved by coordinates/version and matched staged SHA-256:
   - `com.mad.maduikit:maduikit-components-iosx64:0.1.0-alpha01`: `6fabde6c67b5c8eadd5dd3458747bafd4e32504f4a6856e02e5e03e0deab0903`
   - `com.mad.maduikit:maduikit-theme-iosx64:0.1.0-alpha01`: `ea87f29e9fe676cf981df23bab5794b27cac4f891aff17f349965694306d4f59`
5. Xcode built an unsigned x86_64 simulator application; opt-in configuration and architecture were checked.
6. Simulator installed and launched `dev.maduikit.demo`; native capture was 1179 × 2556. Pixel inspection found 36 gradient-marker rows. Human-facing visual review confirmed synthetic Chinese headings and horizontal/vertical gradients.

## Evidence

Actions artifact `public-ios-verified-consumer-intel` (14487957367) contains build/check logs, pins, architecture, launch, screenshot and proof.
- ZIP SHA-256: `5aa2eeed6e3d8e0c5b260ac1d523bac99fd1b35509662e3b9150753e31a8e2e7`.
- `iOS-Verified-Consumer-Intel.png` SHA-256: `e2012aaa1ce78b521bbd47b63fc3bc6e26fed0dda1ff50cbe66ddb97ba9c4d2a`.

An earlier Intel attempt exposed an actual macOS path issue: the generation wrapper wrongly rejected a trusted temporary parent via /var symlink. Codegen 4c12c7b fixes the boundary without allowing symlinks inside a generated bundle, with regression coverage. The successful run uses that fix, not a skipped gate.

## Limits and next gate

This proves clean-checkout generation, external SDK consumption, native compilation and one launch/render on Intel iOS simulator. It does **not** prove ARM64 simulator/device builds, release signing, interaction behavior, accessibility, universal Figma coverage, exact cross-platform pixel parity or the user's private Figma page. No private Figma data was used or published. Production source targets remain unchanged.

Next independent gate: production ARM64 simulator validation on an available standard runner, and subsequent interaction tests. Preserve these acceptance boundaries rather than treating this synthetic smoke as full product completion.

## Follow-up: native filter interaction PASS

[Run 44443969816](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44443969816), job 135291447501, passed on 2026-11-19 at 02:52 UTC.
Tested commit `67fa36d8cdb72b33cbbaa2a80749f38a5a77f045`, branch `ci/ios-filter-intel`. Same Demo/SDK/Codegen pins above, same standard Intel adapter.

The isolated test archive overlays the existing public Books filter host and XCUI project. SDK Kotlin and generated gradient source are unchanged. Native XCTest on iPhone 16 simulator, iOS 26.0.1, x86_64 reported **1 passed, 0 failed, 0 skipped**:
- Initial All books selected; request count 0.
- Native tap Favorites selects it and increments requests to 1.
- Unavailable exposes disabled accessibility semantics.
- Physical coordinate tap at its center leaves Favorites selected and request count 1 (including a 2-second negative wait for unwanted selection).

Three native 1178×2556 screenshots were retained and visually reviewed. The generated gradient marker remained present in all three. This adds narrow selection/disabled-tap evidence, not comprehensive interaction/accessibility validation or private Figma parity.

Artifact `public-ios-filter-intel` (14494430422) ZIP SHA-256:
`eb9670bbfb6a2ba08cf10ef6a177f2a07b767772c93718675d51432641eeb5d8`.
Artifact includes XCUI summary, three screenshots, checksums and an original fresh generation bundle (manifest, diagnostics, source/map). This additional receipt bundle was generated after the test and independently checked against the same compiled checked-in source, not represented as the earlier temporary compiler-gate bundle. Kotlin SHA remains `652457633b3e993965e4aefccc20e60ba0577b697ff04adc713bde7544e8e0e5`.

Resolved external KLIBs matched this run's stage:
- components: `950373a5e6782512a0058c4151e70f550f2e210a410d1128eb040aec50c02da9`
- theme: `9ff30045754c4a1565945c2b291545c8d4ed2f5fe85a7116e5a574ff5da934a4`

These hashes differ from the earlier build; no reproducible-binary claim is made. No SDK product target changes, paid runner or private inputs.
