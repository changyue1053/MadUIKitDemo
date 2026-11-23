"""Bind the same-run intermediate candidate and both native runtime receipts."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import zlib

BASE = "4c10c401bdf59a8c3986b8489203214af711d810"
PIN = "19c8c1b1fbe75b7d6a6118fdab42048948de091b"
APK = "public-unified-books-android.apk"
IOS_PNG = "accepted-runtime/Independent-iOS-Arm64Simulator-Books.png"
ANDROID_PNG = "MadUIKit-Android-Unified-Books.png"
TRANSFER = "candidate-transfer.json"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def identity():
    return {"base": BASE, "sdk": PIN, "commit": os.environ["GITHUB_SHA"],
            "run": os.environ["GITHUB_RUN_ID"], "attempt": os.environ["GITHUB_RUN_ATTEMPT"]}


def inventory(root, excluded):
    files = {}
    for p in root.rglob("*"):
        assert not p.is_symlink() and (p.is_dir() or p.is_file())
        name = p.relative_to(root).as_posix()
        if p.is_file() and name not in excluded:
            files[name] = sha(p)
    return files


def candidate_metrics(root, files):
    stage = json.loads((root / "stage-before.json").read_text())
    prefix = "versioned-maven/"
    assert {n[len(prefix):]: v for n, v in files.items() if n.startswith(prefix)} == stage["files"]
    assert len(stage["leafs"]) == 6
    apple = json.loads((root / "accepted-runtime/runtime.json").read_text())
    tests = json.loads((root / "test-summary.json").read_text())
    assert tests["result"] == "Passed" and tests["passedTests"] == tests["totalTestCount"] == 1 and tests["failedTests"] == 0
    assert {d["device"]["architecture"] for d in tests["devicesAndConfigurations"]} == {"arm64"}
    assert {d["device"]["platform"] for d in tests["devicesAndConfigurations"]} == {"iOS Simulator"}
    assert apple["runtime"] == "passed" and apple["variant"] == "books"
    assert apple["screen"]["decodedPNG"] is True and apple["screen"]["nonblankCheck"] is True
    assert files[IOS_PNG] == apple["screenshotSha256"] and (root / IOS_PNG).stat().st_size == apple["screenshotBytes"]
    assert (root / "android-apk.sha256").read_text().split() == [files[APK], APK]
    return {"stageSha256": files["stage-before.json"], "apkSha256": files[APK], "iosPngSha256": files[IOS_PNG]}


def png_check(path):
    b = path.read_bytes()
    assert 64 < len(b) <= 20_000_000 and b[:8] == b"\x89PNG\r\n\x1a\n"
    cursor, data, header, ended = 8, bytearray(), None, False
    while cursor + 12 <= len(b):
        size = struct.unpack_from(">I", b, cursor)[0]
        kind = b[cursor+4:cursor+8]
        end = cursor + 12 + size
        assert end <= len(b)
        payload = b[cursor+8:end-4]
        assert zlib.crc32(kind + payload) == struct.unpack_from(">I", b, end-4)[0]
        cursor = end
        if kind == b"IHDR":
            assert header is None
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            data.extend(payload)
        elif kind == b"IEND":
            assert size == 0 and end == len(b)
            ended = True
            break
    assert ended and header is not None
    w,h,depth,colors,compression,filters,interlace = header
    assert 200 <= w <= 3000 and 200 <= h <= 5000 and depth == 8
    assert (compression, filters, interlace) == (0, 0, 0) and colors in (2, 6)
    channels = 3 if colors == 2 else 4
    stride = w * channels + 1
    d = zlib.decompressobj()
    raw = d.decompress(data, stride*h+1)
    assert len(raw) == stride*h and d.eof and not d.unused_data
    # Decode rows so a blank image with varied PNG predictors cannot pass.
    previous = bytearray(stride-1)
    seen = set()
    for y in range(h):
        start = y*stride
        pred, vals = raw[start], bytearray(raw[start+1:start+stride])
        assert pred <= 4
        if pred:
            for x in range(len(vals)):
                a = vals[x-channels] if x >= channels else 0
                up = previous[x]
                c = previous[x-channels] if x >= channels else 0
                if pred == 1: basis = a
                elif pred == 2: basis = up
                elif pred == 3: basis = (a + up)//2
                else:
                    p = a+up-c
                    pa,pb,pc = abs(p-a),abs(p-up),abs(p-c)
                    basis = a if pa <= pb and pa <= pc else up if pb <= pc else c
                vals[x] = (vals[x] + basis) & 255
        if len(seen) < 16:
            seen.update(tuple(vals[x:x+3]) for x in range(0, len(vals), channels*4))
        previous = vals
    if len(seen) < 16:
        raise ValueError("blank screenshot")
    return {"width": w, "height": h, "pngSha256": sha(path)}


def main():
    mode, location = sys.argv[1:]
    root = Path(location)
    if mode == "produce":
        files = inventory(root, set())
        metrics = candidate_metrics(root, files)
        write(root / TRANSFER, {**identity(), **metrics, "files": files})
        return
    transfer = json.loads((root / TRANSFER).read_text())
    for k, v in identity().items():
        assert transfer[k] == v
    extra = {ANDROID_PNG} if mode == "accept" else set()
    assert mode in ("verify", "accept")
    files = inventory(root, {TRANSFER} | extra)
    assert files == transfer["files"]
    metrics = candidate_metrics(root, files)
    for k, v in metrics.items():
        assert transfer[k] == v
    if mode == "accept":
        proof = png_check(root / ANDROID_PNG)
        write(root / "s0-runtime-acceptance.json",
              {**identity(), **metrics, "candidateReceiptSha256": sha(root / TRANSFER),
               "android": {"scope": "installed exact APK, foreground launch, three Books labels; no interaction",
                           "package": "dev.mad.adoption.unified", "systemImage": "android-35/google_apis/x86_64",
                           **proof},
               "ios": {"scope": "arm64 iOS simulator XCTest Books launch and labels; no interaction",
                       "pngSha256": metrics["iosPngSha256"]}})


if __name__ == "__main__":
    main()
