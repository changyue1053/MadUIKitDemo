#!/usr/bin/env python3
"""Create a clean CPF worktree overlay from a trusted, locally cloned and pinned upstream commit."""
import argparse
from hashlib import sha256
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

BASE = Path(__file__).resolve().parent
PAGE_HASH = "652457633b3e993965e4aefccc20e60ba0577b697ff04adc713bde7544e8e0e5"
APP = "composeApp/src/commonMain/kotlin/com/example/cmp_hello/App.kt"
PAGE = "composeApp/src/commonMain/kotlin/dev/maduikit/demo/generated/FigmaProfileScreen.generated.kt"
VERSIONS = "gradle/libs.versions.toml"
OHPM = "harmonyApp/entry/oh-package.json5"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def overlay(tree, source):
    def read(name):
        return (tree / name).read_text(encoding="utf-8")
    text = read(APP)
    require(re.search(r"(?m)^package com\.example\.cmp_hello\s*$", text) is not None
            and re.search(r"\bfun\s+App\s*\(\s*\)", text) is not None,
            "Unexpected upstream App() contract. Review exact source before applying.")
    versions = read(VERSIONS)
    require(all(v in versions for v in ("2.2.21-1.2.0", "1.9.2-1.2.0")), "CPF catalog does not match this probe's version tuple")
    require("gradle-8.9-" in read("gradle/wrapper/gradle-wrapper.properties"), "Gradle wrapper differs from 8.9")
    properties = read("gradle.properties")
    require(re.findall(r"(?m)^[ \t]*rendererBackend[ \t]*=[ \t]*(\S+)[ \t]*$", properties) == ["skia"]
            and re.search(r"(?m)^ohosSkikoVersion=0\.9\.22\.2-1\.2\.0$", properties),
            "Pinned sample uses Skia 0.9.22.2-1.2.0; do not silently change backend")
    require(re.search(r"""["']@cpf-kmp-cmp/compose["']\s*:\s*["']1\.9\.2-1\.2\.0["']""", read(OHPM)) is not None,
            "OHPM Compose bridge differs from 1.9.2-1.2.0")
    require((tree / "harmonyApp/entry/src/main/cpp/napi_init.cpp").is_file(), "Pinned example must provide native NAPI bridge")
    require((tree / "harmonyApp/entry/src/main/ets/pages/Index.ets").is_file(), "Pinned example must provide thin ArkTS Compose host")
    require(any((tree / "composeApp/src/ohosMain").rglob("MainArkUIViewController.kt")),
            "Pinned example must provide the Kotlin/Native ArkUI controller")
    target = tree / PAGE
    require(sha256(source.read_bytes()).hexdigest() == PAGE_HASH, "Synthetic CMP Kotlin SHA mismatch")
    require(not target.exists(), "Refusing to overwrite generated source in vendor tree")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    shutil.copyfile(BASE / "ProbeApp.kt", tree / APP)
    require(sha256(target.read_bytes()).hexdigest() == PAGE_HASH, "Copied source differs")


def stage(repo, commit, destination, page):
    require(bool(re.fullmatch(r"[a-f0-9]{40}", commit)), "Use the audited full Git commit SHA")
    require(not destination.exists(), "Destination already exists")
    with tempfile.TemporaryDirectory(prefix=".cpf-stage-", dir=destination.parent) as tmp:
        tmp = Path(tmp)
        tree, archive = tmp / "worktree", tmp / "upstream.tar"
        tree.mkdir()
        # Read a locally available commit only; do not fetch or execute vendor code.
        subprocess.run(["git", "-C", str(repo), "archive", "--format=tar", "-o", str(archive), commit], check=True)
        with tarfile.open(archive, "r") as source:
            source.extractall(tree, filter="data")
        overlay(tree, page)
        (tree / "maduikit-provenance.txt").write_text(
            f"cpf_upstream_commit={commit}\nshared_compose_sha256={PAGE_HASH}\n", encoding="utf-8")
        require(not destination.exists(), "Destination appeared during staging")
        tree.rename(destination)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, required=True)
    ap.add_argument("--commit", required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--page", type=Path, required=True)
    args = ap.parse_args()
    try:
        stage(args.repo.resolve(), args.commit, args.out.resolve(), args.page.resolve())
    except (OSError, ValueError, subprocess.CalledProcessError, tarfile.TarError) as e:
        ap.exit(2, f"CPF overlay not staged: {e}\n")
    print("Pinned CPF overlay staged. This does not prove a native build.")


if __name__ == "__main__":
    main()
