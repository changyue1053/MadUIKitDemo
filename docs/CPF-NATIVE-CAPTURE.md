# CPF verified native pair retention

Public synthetic probe only. No HAP, signing, device installation or runtime acceptance.

## Verified run

- [Run 44445917660](https://github.com/changyue1053/MadUIKitDemo/actions/runs/44445917660), attempt 1, job 135297892754: success at 2026-11-19 02:51 UTC.
- Tested commit: `5d83233115c63c4a86a4bad6c3175ebd50fee242`, isolated branch `ci/cpf-native-capture`.
- Artifact: `cpf-native-pair-44445917660-1`, ID `14493234048`, 7-day retention.
- Archive SHA256: `074f6cf393d12bc52a1bf88ad08fcce65074dd7eceb051f440ee1b0861c8b44b`.
- Provenance SHA256 independently printed in successful CI logs: `f4ccd1adbfba4e60e9923ef6facd2c9ceec4dabff231fb0ea139bb62defb7d2f`.

## Same-run pair

| File | SHA256 |
|---|---|
| libkn.so | 02984cb2061bde2cfaa1767a8e588fb3b10b03b7565bc93aa5302a2c5c08b68c |
| libkn_api.h | 6f4d862261c0bc2a0c4e0675f6f06860e1ee543a835050ad727515619e83542b |

CI captures only after compile/link and ELF/controller checks succeed. Upload allowlist is exactly the pair plus provenance. No credentials, project folders, caches or private design inputs are retained.

The downloaded archive matched GitHub's digest. Extraction rejected unexpected paths and symbolic links. Provenance digest matched independent CI logs; run, attempt, commit and both file hashes matched. Local readelf confirmed AArch64 DYN and a defined MainArkUIViewController export; the matching header declares the controller.

This closes artifact retention, not HarmonyOS packaging. The binary differs from the previous run, so cross-run binary reproducibility is NOT claimed. Fusion partial-linkage diagnostics remain; compatible OHPM HAR/native bridge compilation and real startup/render tests are still required. Production SDK and Demo main are unchanged.
