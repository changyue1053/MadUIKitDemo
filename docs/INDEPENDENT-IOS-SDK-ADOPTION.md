# Independent iOS SDK adoption: native PASS

Supersedes the earlier partial result below. [Run44525110754](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44525110754), job135563483790, passed2026-11-19 13:00 UTC.
Tested `cc1f820d00206c8b322c7022ec582f8bb93b6670` on `ci/ios-sdk-adoption`.

The independent Gradle build declares only components SDK coordinate and resolves real versioned Maven metadata plus transitive theme. SDK19c8c1 Kotlin remains unchanged; isolated Intel target adapter only. No direct loose KLIB import, SDK source substitution, Codegen or registry release.

Verified stages:
- SDK staging304.91s; resolution31.63s.
- Explicit standalone framework compile/link484.28s.
- Simulator boot236.94s; Xcode build252.96s.
- Xcode host phase verifies all4 prebuilt framework files against receipt, expected SDK and architecture; no Gradle invocation inside Xcode.
- XCUI130.18s, **1 passed,0 failed/skipped**. Actual iPhone16 simulator iOS26.0.1 x86_64 displays Independent iOS SDK consumer, All books and Favorites.
- Native1178×2556 screenshot visually inspected and SHA verified. This deliberately minimal unstyled host has adjacent tab labels; no polished design claim.

Artifact14533302496 ZIP SHA256 `fcc55ebacd63888259679918785ca7cee5aac644250b0381c97615721a6a9498` retains Maven stage, graph/variant reports, per-stage status/durations, framework receipt, XCUI summary and native screenshot.
This run's KLIB hashes:
- components `34aa189998a64623693f266b97ba5fdbd2d42f9059b277f3440e83521f889f92`
- theme `031d3ba05018b84b2f4e53c97150b9fc702b9866f5dc4f8a0d8ec235076492bc`

Splitting framework linking from the Xcode phase resolved this workflow, but does not establish the exact root cause of the earlier stall. No unchanged retry was used for this pass. Scope remains Intel simulator adoption/launch, not ARM64/device, interaction behavior, production iosX64 support, release signing or private Figma parity.

## Historical partial run


[Run44517431166](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44517431166), job135536979966, reached the45-minute limit and was cancelled.
Tested commit `d429f39b94cbac0a996f9f7da2d7677e6545b069`, isolated `ci/ios-sdk-adoption`.

## Proven
- Standard macos-15-intel, Xcode26.0.1; SDK19c8c1b1fbe75b7d6a6118fdab42048948de091b.
- Temporary SDK iosX64 Gradle adapter only; product Kotlin bytes unchanged.
- Fresh independent Gradle root declares only versioned components SDK coordinate, no direct theme, source substitution, loose KLIB import or Codegen.
- Gradle Maven metadata resolves components root→components-iosx64→theme root→theme-iosx64. Actual variant native/ios_x64 and artifact bytes verified against filesystem Maven stage.
- Components KLIB SHA256 `2ddde49bf1a812d46bb530ea43b2a8773a617945763148add661025cd78b0308`.
- Theme KLIB SHA256 `3db994cc12944655a43673575a2a0e66afadd54f5210d663e8fa9daa3b492ee3`.

## Not proven
Xcode log ends at the framework build-script invocation, with no subsequent Kotlin task output or build-success marker. Cause of that stall is not established. Consumer framework compile/link, app launch, XCUI labels and screenshot are **unverified**, not passed.

An earlier run44515801442 reached the same metadata gate but failed because the new helper lacked its executable bit. Corrected only the helper file mode before this run. No unchanged or further retry performed after the timeout.

## Retained evidence
Artifact14528803052 `public-ios-sdk-adoption` includes Maven stage, exact graph/variant report, SDK staging/resolution logs and Xcode log.
ZIP SHA256 `3954b1364319597930f07e82b746297bfceffb6f5d0dbf495492adaf3ae556c1`, downloaded and verified.

Next investigation should isolate and instrument the framework shell/Gradle invocation before another end-to-end simulator run. This is not ARM64/device acceptance, production iosX64 support, remote registry release or private-design parity. No private input, personal computer or main change.
