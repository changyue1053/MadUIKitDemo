#!/usr/bin/env python3
"""Check the synthetic sample source contract without Android SDK or Xcode."""
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parents[1]
shared = root / "composeApp/src"
kotlin = shared / "commonMain/kotlin/dev/maduikit/demo"
generated = kotlin / "generated/FigmaProfileScreen.generated.kt"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--generated-source", type=Path, required=True, help="Required verified Codegen bundle source to compare byte-for-byte.")
args = parser.parse_args()
def require(value, message):
    if not value:
        raise SystemExit(message)

try:
    source_path = args.generated_source
    require(source_path.name == generated.name and not source_path.is_symlink(), "Expected ordinary canonical generated source")
    generated_bytes = generated.read_bytes()
    require(generated_bytes == source_path.read_bytes(), "Demo altered generated Kotlin")
    manifest_path = source_path.with_name("manifest.json")
    diagnostics_path = source_path.with_name("diagnostics.json")
    require(manifest_path.is_file() and not manifest_path.is_symlink(), "Missing or linked Codegen manifest")
    require(diagnostics_path.is_file() and not diagnostics_path.is_symlink(), "Missing or linked generation diagnostics")
    generated_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    diagnostics = json.loads(diagnostics_path.read_text(encoding="utf-8"))
    require(diagnostics.get("ok") is True and diagnostics.get("errors") == [], "Generation did not succeed")
    require(generated_manifest.get("schemaVersion") == diagnostics.get("schemaVersion") == 1, "Unsupported receipt schema")
    require(generated_manifest.get("target") == "cmp", "Expected CMP target")
    require(generated_manifest.get("inputSha256") == diagnostics.get("inputSha256") and
            re.fullmatch(r"[0-9a-f]{64}", str(generated_manifest.get("inputSha256"))), "Input receipts disagree")
    require(hashlib.sha256(generated_bytes).hexdigest() == generated_manifest["files"][generated.name],
            "Generated Kotlin does not match Codegen manifest")
except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
    raise SystemExit(f"Invalid generated bundle: {error}")
manifest = ET.parse(shared / "androidMain/AndroidManifest.xml")
scheme = ET.parse(
    root / "iosApp/MadUIKitDemo.xcodeproj/xcshareddata/xcschemes/MadUIKitDemo.xcscheme"
)
proj = (root / "iosApp/MadUIKitDemo.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
ns = "{http://schemas.android.com/apk/res/android}"
assert manifest.find("./application/activity").get(ns + "name") == ".MainActivity"
assert manifest.find("./application/activity").get(ns + "exported") == "true"
assert "android.intent.action.MAIN" in (shared / "androidMain/AndroidManifest.xml").read_text()
entries = scheme.findall(".//BuildableReference")
assert entries and all(x.get("BlueprintIdentifier") in proj for x in entries)
assert proj.count("{") == proj.count("}")
assert (root / "scripts/ios-framework.sh").is_file()
controller = (shared / "iosMain/kotlin/dev/maduikit/demo/DemoController.kt").read_text()
assert "ComposeUIViewController { DemoScreen() }" in controller
swift = (root / "iosApp/DemoApp.swift").read_text()
assert "import MadUIKitDemoShared" in swift and "DemoControllerKt.makeDemoViewController()" in swift
source = generated.read_text(encoding="utf-8")
assert re.search(r"^package dev\.maduikit\.demo\.generated\s*$", source, re.MULTILINE)
assert re.search(r"@Composable\s+(?:public\s+)?fun FigmaProfileScreen\s*\(", source)
assert "FigmaProfileScreen()" in (kotlin / "DemoScreen.kt").read_text()
assert "includeBuild(" not in (root / "settings.gradle.kts").read_text()
assert "mavenLocal(" not in (root / "settings.gradle.kts").read_text()
print("synthetic sample source contract passed (not an Android or iOS build).")
