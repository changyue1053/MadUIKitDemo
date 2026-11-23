"""Allowlisted, bounded gate evidence without any runner log bytes."""
import hashlib
import json
from pathlib import Path
import os
import re
import sys

out, gate, code = Path(sys.argv[1]), sys.argv[2], int(sys.argv[3])
allowed = {"validator-build", "validator-prove", "boot", "boot-frame", "frame-check",
           "android-sdk", "stage", "android-resolve", "android-build", "resolution",
           "framework", "host-build", "test"}
payload = {"status": "candidate-ready" if code == 0 else "not-accepted",
           "gate": gate, "exit": code, "run": os.environ.get("GITHUB_RUN_ID"),
           "attempt": os.environ.get("GITHUB_RUN_ATTEMPT"), "commit": os.environ.get("GITHUB_SHA"),
           "stages": {}}
for name in sorted(allowed):
    path = out / f"{name}.status.json"
    if path.is_file():
        status = json.loads(path.read_text())
        payload["stages"][name] = {k: status[k] for k in ("status", "exitCode", "durationSeconds")}
name = {"ios-resolve": "resolution", "ios-framework": "framework", "ios-test": "test"}.get(gate, gate)
log = out / f"{name}.log"
if code and name in allowed and log.is_file():
    causal = log.read_text(errors="replace").partition("* What went wrong:")[2].partition("* Try:")[0]
    payload["firstGradleCauseClass"] = (
        "androidx-disabled-detector" if "contains AndroidX dependencies" in causal and "android.useAndroidX" in causal else
        "dependency-resolution" if re.search(r"Could not (find|resolve|download|GET|HEAD)", causal) else
        "other-gradle-cause-withheld" if causal.strip() else "no-gradle-causal-block")
stage = out / "stage-before.json"
if stage.is_file() and stage.stat().st_size:
    try:
        doc = json.loads(stage.read_bytes())
        payload["verifiedStage"] = {"manifestSha256": hashlib.sha256(stage.read_bytes()).hexdigest(),
                                    "files": len(doc["files"]), "leafs": doc["leafs"]}
    except (ValueError, KeyError):
        pass
report = out / "android-resolution.txt"
if report.is_file():
    rows = report.read_text().splitlines()
    if len(rows) == 2 and all(re.fullmatch(r"com\.mad\.maduikit:maduikit-(components|theme)-android:0\.1\.0-alpha01 sha256=[0-9a-f]{64}", x) for x in rows):
        payload["androidResolution"] = rows
ios = out / "ios-resolution.txt"
if ios.is_file():
    payload["iosResolutionSha256"] = hashlib.sha256(ios.read_bytes()).hexdigest()
(out / "diagnostic" / "macos-receipt.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
