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
parser.add_argument("--generated-source", type=Path, help="Optional Codegen output to compare byte-for-byte.")
args = parser.parse_args()
if args.generated_source is not None:
    generated_bytes = generated.read_bytes()
    assert generated_bytes == args.generated_source.read_bytes(), "Demo altered generated Kotlin"
    manifest_path = args.generated_source.with_name("manifest.json")
    if manifest_path.is_file():
        generated_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert hashlib.sha256(generated_bytes).hexdigest() == generated_manifest["files"][generated.name], (
            "Generated Kotlin does not match Codegen manifest"
        )
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
