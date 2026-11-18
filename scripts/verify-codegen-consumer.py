#!/usr/bin/env python3
"""Gate the synthetic Demo on a fresh, verified Codegen gradient bundle."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--codegen-root", type=Path, default=root.parent / "MadUIKitCodegen")
args = parser.parse_args()
codegen = args.codegen_root.resolve()
wrapper = codegen / "scripts/generate-verified.py"
launcher = codegen / "build/install/MadUIKitCodegen/bin/MadUIKitCodegen"
if not wrapper.is_file() or not launcher.is_file():
    raise SystemExit("Build MadUIKitCodegen with the verified-generation wrapper first: ./gradlew check installDist")
with tempfile.TemporaryDirectory(prefix="mad-demo-consumer-") as temporary:
    bundle = Path(temporary) / "bundle"
    subprocess.run([sys.executable, str(wrapper), "--launcher", str(launcher),
                    "--input", str(codegen / "fixtures/figma/gradient.file-nodes.json"),
                    "--node", "3:1", "--fit-width", "--out", str(bundle)], check=True)
    subprocess.run([sys.executable, str(root / "scripts/check-structure.py"),
                    "--generated-source", str(bundle / "FigmaProfileScreen.generated.kt")], check=True)
print("Demo consumer gate passed: checked-in Kotlin equals a fresh verified synthetic bundle.")
