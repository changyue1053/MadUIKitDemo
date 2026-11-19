# Independent iOS SDK adoption: metadata PASS, build/runtime unverified

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
