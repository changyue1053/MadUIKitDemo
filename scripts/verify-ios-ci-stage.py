"""Verify the two pinned simulator KLIB files and their root metadata links."""
import hashlib
import json
import sys
from pathlib import Path
from zipfile import ZipFile

GROUP = "com.mad.maduikit"
VERSION = "0.1.0-alpha01"
MODULES = ("maduikit-theme", "maduikit-components")
TARGET = "iossimulatorarm64"


def verify(stage: Path):
    base = stage.joinpath(*GROUP.split("."))
    results = []
    for module in MODULES:
        native = module + "-" + TARGET
        stem = base / module / VERSION / f"{module}-{VERSION}.module"
        root = json.loads(stem.read_text(encoding="utf-8"))
        if root["component"]["group"] != GROUP or root["component"]["version"] != VERSION:
            raise ValueError(f"unexpected coordinates: {stem.name}")
        links = [
            v["available-at"] for v in root["variants"]
            if v.get("available-at", {}).get("module") == native
        ]
        if not any(a.get("group") == GROUP and a.get("version") == VERSION for a in links):
            raise ValueError(f"root metadata does not advertise {native}:{VERSION}")
        artifact = base / native / VERSION / f"{native}-{VERSION}.klib"
        with ZipFile(artifact) as klib:
            if klib.testzip() is not None or not any(n.endswith("/manifest") for n in klib.namelist()):
                raise ValueError(f"invalid KLIB structure: {artifact.name}")
        with artifact.open("rb") as f:
            digest = hashlib.sha256()
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                digest.update(chunk)
        results.append({"coordinates": f"{GROUP}:{native}:{VERSION}", "bytes": artifact.stat().st_size,
                        "sha256": digest.hexdigest()})
    return results


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: verify_apple_stage.py MAVEN_STAGE")
    try:
        print(json.dumps(verify(Path(sys.argv[1])), indent=2))
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"staged Apple KLIB check failed: {error}")
