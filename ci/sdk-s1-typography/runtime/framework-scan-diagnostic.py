"""Classify the unchanged transfer regex; only fixed role/marker families and counts."""
import json
import os
import pwd
from pathlib import Path
import runpy
import sys

ROLE_PATHS = {
    "static-archive": "MadUIKitS1Adopter",
    "generated-header": "Headers/MadUIKitS1Adopter.h",
    "module-map": "Modules/module.modulemap",
    "framework-plist": "Info.plist",
}
FAMILIES = ("home-directory", "workspace-directory", "token-like", "private-key-like", "unclassified")
ROOT = b"/Users/runner"

def classify(data, pattern, trusted_root):
    counts = dict.fromkeys(FAMILIES, 0)
    exact_nul = 0
    bounded_atom = 0
    for match in pattern.finditer(data):
        matched = match.group(0)
        lower = matched.lower()
        if lower.startswith(b"/users/"):
            counts["home-directory"] += 1
            # Never accept a case-folded name, alternate delimiter, or a longer prefix.
            if (trusted_root and matched == ROOT and
                data[match.end():match.end()+1] == b"\0"):
                exact_nul += 1
                if match.start() == 0 or data[match.start()-1:match.start()] == b"\0":
                    bounded_atom += 1
        elif lower.startswith(b"/workspace/"):
            counts["workspace-directory"] += 1
        elif lower.startswith(b"gh"):
            counts["token-like"] += 1
        elif lower.startswith(b"begin "):
            counts["private-key-like"] += 1
        else:
            counts["unclassified"] += 1
    return {"markerCounts": counts, "exactTrustedRunnerRootNulCount": exact_nul,
            "exactTrustedRunnerRootNulAtomCount": bounded_atom}

def run():
    if len(sys.argv) != 3:
        raise SystemExit("Invalid diagnostic arguments")
    root, packer = map(Path,sys.argv[1:])
    implementation = runpy.run_path(str(packer))
    marker, limits = implementation["PRIVATE_MARKERS"], implementation["LIMITS"]
    expected=set(ROLE_PATHS.values())
    if expected != set(implementation["ALLOWED"]) or expected != set(limits):
        raise SystemExit("Unexpected pinned packer role schema")
    trusted_path = Path(ROOT.decode())
    trusted = (Path.home().resolve() == trusted_path and
               Path(pwd.getpwuid(os.getuid()).pw_dir).resolve() == trusted_path)
    observed = list(root.rglob("*"))
    if root.is_symlink() or not root.is_dir() or any(p.is_symlink() or not (p.is_dir() or p.is_file()) for p in observed):
        raise SystemExit("Invalid framework inventory")
    if {p.relative_to(root).as_posix() for p in observed if p.is_file()} != expected:
        raise SystemExit("Unexpected framework files")
    result = {}
    for role, rel in ROLE_PATHS.items():
        path = root / rel
        if not 0 < path.stat().st_size <= limits[rel]:
            raise SystemExit("Unexpected framework member size")
        result[role] = classify(path.read_bytes(), marker, trusted)
    count = sum(sum(v["markerCounts"].values()) for v in result.values())
    exact = sum(v["exactTrustedRunnerRootNulAtomCount"] for v in result.values())
    print(json.dumps({
        "purpose": "synthetic-framework-transfer-diagnostic-only",
        "transferAuthorized": False,
        "trustedRunnerHomeVerified": trusted,
        "roles": result,
        "hasOnlyExactTrustedRunnerRootNulMarkers": bool(exact and count == exact),
    }, sort_keys=True, indent=2))

if __name__ == "__main__":
    try:
        run()
    except (OSError, KeyError, TypeError, ValueError):
        raise SystemExit("Diagnostic failed closed") from None
