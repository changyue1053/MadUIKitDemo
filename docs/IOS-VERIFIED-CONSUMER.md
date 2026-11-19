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
