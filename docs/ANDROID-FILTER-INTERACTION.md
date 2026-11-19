# Android public Books filter native interaction: PASS

[Run44466417608 attempt2](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44466417608/attempts/2), job135385389131, passed2026-11-19 at06:37 UTC.
Tested commit `fe06b713ab43e378cfe2db50f2bff6a2dbf21eb3` on isolated branch `ci/android-filter-interaction`.
SDK `19c8c1b1fbe75b7d6a6118fdab42048948de091b`, Codegen `ab86297465b3cc0107be493a2ce9c1a5ece96be6`.

## Verified
- Codegen aggregate checks including24 safety checks, fresh Demo bundle gate and10 consumer checks passed.
- External SDK AARs resolved and matched filesystem stage; actual APK compiled/installed/launched.
- Android15/API35 Google APIs x86_64 emulator, Pixel2 profile.
- Native UIAutomator observed All books selected, request count0.
- Actual adb tap at Favorites observed center(386,1013) selected Favorites and count1.
- Unavailable exposed disabled semantics. Actual center tap(650,1013), followed by2-second wait and fresh native UI dump, preserved Favorites/count1.
- Three native1080×1920 screenshots visually reviewed; UI XML, taps, bundle and hashes retained.
- Public host source is byte-identical to successful Intel iOS host: SHA256 `ddc55c7835fea2ee870e5e4d1b7fe97dd75d699e7d02e576355de53e6bf5a7fa`.

## Evidence
Use successful artifact14505087977 `public-android-filter`, not earlier failure artifact14502426791.
- ZIP SHA256 `0ee74c8aeadf62430215793b3f6b43e06527fc00485be681312aa3183cf178d9`.
- Installed APK SHA256 `618abaa6f2d5373015872a9c2688122996e08c588e8c22932c59f503ced27b19`.
- Components AAR `f0daeaf2f10316b0d56493d875fb0e376a1b23821ad2765f81b6790c54a93ed5`.
- Theme AAR `c363ceb5ea428109755aed91c73a5500cd5574a5476fc945737627d07692649b`.

Artifact screenshots and original additional fresh generation receipt bundle hashes were verified after download. Bundle was independently generated after APK compilation, checked against compiled source, and is not claimed to be the earlier temporary compiler-gate directory.

## Limits
Narrow public synthetic selection/disabled-tap behavior only. Not physical device, full accessibility, private Figma pixel parity, exhaustive interaction, or Harmony runtime acceptance. iOS comparison shares host and SDK source pin, not Codegen pin or binary output.

First attempt stopped at official Maven HTTP429 before Codegen configuration. One unchanged retry was run after the same dependency chain succeeded in the separate atomic resource job. No repeated retry, production main change or private input.
