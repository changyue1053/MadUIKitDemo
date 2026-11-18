#!/usr/bin/env python3
"""Accept only complete matching public synthetic Codegen bundles."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--codegen-root", required=True, type=Path)
args = parser.parse_args()
codegen = args.codegen_root.resolve()
checker = root / "scripts/check-structure.py"
with tempfile.TemporaryDirectory(prefix="mad-consumer-test-") as directory:
    work = Path(directory)
    bundle = work / "accepted"
    subprocess.run([sys.executable, str(codegen / "scripts/generate-verified.py"),
        "--launcher", str(codegen / "build/install/MadUIKitCodegen/bin/MadUIKitCodegen"),
        "--input", str(codegen / "fixtures/figma/gradient.file-nodes.json"),
        "--node", "3:1", "--fit-width", "--out", str(bundle)], check=True)
    def check(path, success):
        result = subprocess.run([sys.executable, "-O", str(checker), "--generated-source",
            str(path / "FigmaProfileScreen.generated.kt")], capture_output=True, text=True)
        assert (result.returncode == 0) == success, (path, result.stdout, result.stderr)
    check(bundle, True)
    def edit(path, action):
        value = json.loads(path.read_text())
        action(value)
        path.write_text(json.dumps(value))
    cases = {
        "missing-manifest": lambda p: (p/"manifest.json").unlink(),
        "missing-diagnostics": lambda p: (p/"diagnostics.json").unlink(),
        "missing-source": lambda p: (p/"FigmaProfileScreen.generated.kt").unlink(),
        "tampered-source": lambda p: (p/"FigmaProfileScreen.generated.kt").write_text("// stale"),
        "failed-diagnostics": lambda p: edit(p/"diagnostics.json", lambda x:x.update(ok=False)),
        "manifest-hash": lambda p: edit(p/"manifest.json", lambda x:x["files"].update({"FigmaProfileScreen.generated.kt":"0"*64})),
        "input-receipts": lambda p: edit(p/"diagnostics.json", lambda x:x.update(inputSha256="0"*64)),
        "malformed-manifest": lambda p: (p/"manifest.json").write_text("[]"),
    }
    for name, mutate in cases.items():
        output = work/name
        shutil.copytree(bundle, output)
        mutate(output)
        check(output, False)
    omitted = subprocess.run([sys.executable, str(checker)], capture_output=True)
    assert omitted.returncode != 0
print("Demo verified-consumer smoke: 10 checks passed (also with Python optimization).")
