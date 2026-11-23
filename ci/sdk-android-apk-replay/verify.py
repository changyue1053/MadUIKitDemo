"""Bind original same-stage public ZIP to one verified Android runtime replay."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import os
import stat
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "sdk-unified-stage"))
from finalize import png_check  # exact inherited verifier; no Kotlin/Gradle invocation

SOURCE = {
    "run": "45193292225",
    "attempt": "1",
    "commit": "50705ee6c3588d7015375c5cde793982ddbc36a0",
    "artifact": 14830601661,
    "archiveBytes": 10151432,
    "archiveSha256": "db32a831aa1376e0f6557db4a7be6395d77bec988b363c5bb68b4dd7573161d6",
    "transferSha256": "9dc3ea36a3685257240f39531fca5564f2224f3e59bc14eb4acc7980319c9294",
    "stageSha256": "0b43cedaa3d6a7733512cd63f5a047ce9b92b2dd89e091da445778e276f1dcf3",
    "apkSha256": "415e45f3a5f6d8e40dc4e3fc2bab03d833e18d3626549d0423fefe124c569558",
}
SDK = "19c8c1b1fbe75b7d6a6118fdab42048948de091b"
APK = "public-unified-books-android.apk"
PNG = "MadUIKit-Android-Unified-Books.png"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def extract(original, out):
    assert original.stat().st_size == SOURCE["archiveBytes"] and sha(original.read_bytes()) == SOURCE["archiveSha256"]
    with zipfile.ZipFile(original) as z:
        members = z.infolist()
        names = {m.filename for m in members if not m.is_dir()}
        assert len(members) == len({m.filename for m in members})
        assert all(not PurePosixPath(m.filename).is_absolute() and ".." not in PurePosixPath(m.filename).parts
                   and "\\" not in m.filename and not stat.S_ISLNK(m.external_attr >> 16) for m in members)
        assert sum(m.file_size for m in members) <= 150_000_000 and z.testzip() is None
        transfer = z.read("candidate-transfer.json")
        assert sha(transfer) == SOURCE["transferSha256"]
        receipt = json.loads(transfer)
        assert all(receipt[k] == SOURCE[k] for k in ("run", "attempt", "commit", "apkSha256", "stageSha256"))
        assert receipt["sdk"] == SDK
        assert names == set(receipt["files"]) | {"candidate-transfer.json"}
        assert all(sha(z.read(name)) == digest for name, digest in receipt["files"].items())
        assert sha(z.read("stage-before.json")) == SOURCE["stageSha256"]
        assert (apk := z.read(APK)) and sha(apk) == SOURCE["apkSha256"]
        out.write_bytes(apk)


def accept(apk, out, guest):
    assert sha(apk.read_bytes()) == SOURCE["apkSha256"]
    profile = json.loads(guest.read_text())
    assert profile["api"] == 35 and profile["abi"] == "x86_64"
    proof = png_check(out / PNG)
    data = {
        "sourceCandidate": {**SOURCE, "sdk": SDK},
        "runtimeReplay": {"run": os.environ["GITHUB_RUN_ID"], "attempt": os.environ["GITHUB_RUN_ATTEMPT"],
                          "commit": os.environ["GITHUB_SHA"], **profile},
        "package": "dev.mad.adoption.unified", "launcher": "dev.mad.adoption.MainActivity",
        "scope": "exact APK installed; foreground launch and public Books labels only; no interaction",
        "originalCapture": proof,
    }
    (out / "android-replay.json").write_text(json.dumps(data, sort_keys=True, indent=2)+"\n")


if __name__ == "__main__":
    mode, *paths = sys.argv[1:]
    if mode == "extract":
        extract(*map(Path, paths))
    elif mode == "accept":
        accept(*map(Path, paths))
    else:
        raise SystemExit(2)
