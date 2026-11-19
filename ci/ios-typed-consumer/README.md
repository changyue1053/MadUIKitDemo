# Isolated generated typed-component / versioned SDK iOS seam

## Proposed branch and run

New branch `ci/ios-typed-consumer` from the successful isolated adoption commit `cc1f820d00206c8b322c7022ec582f8bb93b6670`. Add ONLY this directory and `.github/workflows/ios-typed-consumer.yml`. Preserve Demo main and SDK repository. Do not push or run until review. Exactly one standard `macos-15-intel` job, 60-minute outer bound and 15-minute individual stage bounds. No paid runner, user Mac, runtime download, live/private Figma or registry release.

Pins: SDK `19c8c1b1fbe75b7d6a6118fdab42048948de091b`; Codegen `7276d8f3843a91ec5394e527fcbd1a63ad99a712`. Proven harness: run44525110754, standard Intel independent Maven consumer, framework built outside Xcode. This is a new generated-code/font/receipt seam, not a repeated handwritten Books test.

## Execution

1. Check exact source pins. Copy SDK privately into runner temp; add only `iosX64()` target to existing Gradle modules, asserting all SDK Kotlin source remains unchanged.
2. Stage versioned components and theme KMP/iOS artifacts to temporary Maven. Consumer is a separate Gradle build with exclusive Maven group resolution and checks artifact versions, target attributes, SHA matches and transitive theme edge. No sibling source inclusion or loose KLIB linking.
3. Build exact Codegen and run its checks. Author only public synthetic snapshots: checked-in single filter-tab sample plus `Synthetic Brand` mapped to body. Generate enabled and disabled configurations separately; use the real wrapper and retain original manifests/maps/source hashes.
4. Copy generated Kotlin bytes unmodified. Host supplies only selected state, counted callback, and FontFamily.Serif. It does not hand-author tabs or intercept taps. `verifyGeneratedBinding` is a Kotlin compile prerequisite and rechecks exact bytes/inputs/receipts.
5. Link each configuration outside Xcode; retain framework hashes and verify those hashes in the Xcode build phase. Separate derived data and result bundles per configuration prevent cached-app evidence confusion.
6. XCTest launches the actual app, observes Books and initial host state, taps the actual label coordinate once, requires enabled request1/selectedtrue or disabled request0/selectedfalse, and retains native before/after PNGs. Disabled BOOLEAN is source-authored, so two sequential builds are intentional; no generated string replacement or runtime disable substitute.

## Local validation already done

Bash syntax and Python compile checks passed. Exact public generator source was compiled with Kotlin2.2.21 locally. Both actual generated bundles and verify-only passed. Modified consumer Kotlin and omitted font map were rejected by the compile prerequisite. Restored inputs passed.

Generated source SHA256:
- enabled `44a8dad7ec063a81609088a435275959065bb0069b0e258349a8a656a8559311`
- disabled `6d2018c0dac29e0e7b76e85a4910b83cfc1bccd75fe3d4fd9efbcab786761579`

Not yet validated: new iOS KLIB/Swift compilation, XCTest accessibility discovery/coordinate interaction, font rendering or screenshots. This patch is ready for review, not a mobile pass claim. The Swift EXPECT_ENABLED token is filled only in runner-temp test source for each configuration; generated Kotlin is never edited. SDK additions are local target adapters, not production target changes. Screenshots are test artifacts, never fabricated.
