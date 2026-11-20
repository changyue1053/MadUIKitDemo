"""Select one exact iOS 26.4.1 iPhone 17 Pro; retain sanitized public runtime evidence."""
import argparse
import json
from pathlib import Path
import re
import sys

# The runner manifest names the simulator iOS 26.4 and lists OS 26.4.1.
# Apple’s simulator catalog reports that ARM64 patch as 23E254a.
# Confirm the CoreSimulator identifier and all fields on the actual runner.
IOS_ID = r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9]+(?:-[0-9]+){0,2}"
VERSION = r"[0-9]+(?:\.[0-9]+){0,2}"
BUILD = r"[0-9]{2}[A-Z][0-9]+[a-z]?"
RUNTIME = ("com.apple.CoreSimulator.SimRuntime.iOS-26-4", "26.4.1", "23E254a")
DEVICE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"


def validated(value, pattern):
    if isinstance(value, str) and len(value) <= 80 and re.fullmatch(pattern, value):
        return value
    return None


def runtime_available(runtime):
    return (runtime.get("identifier"), runtime.get("version"), runtime.get("buildversion")) == RUNTIME and runtime.get("isAvailable") is True


def candidates(data):
    rows = []
    pinned_rows = available_exact_rows = 0
    for runtime in data["runtimes"]:
        pinned_rows += runtime.get("identifier") == RUNTIME[0]
        available_exact_rows += runtime_available(runtime)
        ident = validated(runtime.get("identifier"), IOS_ID)
        if ident is None:
            continue
        available = runtime.get("isAvailable")
        rows.append(dict(identifier=ident,
                         version=validated(runtime.get("version"), VERSION),
                         build=validated(runtime.get("buildversion"), BUILD),
                         available=available if isinstance(available, bool) else None))
    return dict(schemaVersion=1, observedIosRows=len(rows), truncated=len(rows) > 32,
                pinnedIdentifierRows=pinned_rows, availableExactRows=available_exact_rows,
                candidates=rows[:32])


def select(data, expected_udid=None):
    rows = [r for r in data["runtimes"] if r.get("identifier") == RUNTIME[0]]
    if len(rows) != 1:
        raise ValueError("Expected exactly one runtime with the pinned iOS 26.4 identifier")
    runtime = rows[0]
    build = runtime.get("buildversion")
    if not runtime_available(runtime):
        raise ValueError("Pinned iOS 26.4.1 (23E254a) runtime not available")
    types=[t for t in data["devicetypes"] if t.get("identifier")==DEVICE and t.get("name")=="iPhone 17 Pro"]
    if len(types)!=1:
        raise ValueError("Exact simulator device type is not installed")
    valid=[d for d in data["devices"].get(runtime["identifier"],[]) if d.get("deviceTypeIdentifier")==DEVICE
           and d.get("name")=="iPhone 17 Pro" and d.get("isAvailable") is True
           and re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}",d.get("udid",""))]
    chosen,=valid
    expected_state="Booted" if expected_udid else "Shutdown"
    if chosen.get("state")!=expected_state or (expected_udid and chosen["udid"]!=expected_udid):
        raise ValueError("Wrong guest or simulator state")
    return dict(udid=chosen["udid"],runtimeId=runtime["identifier"],
                runtimeVersion=runtime["version"],runtimeBuild=build,
                deviceType=DEVICE,deviceName=chosen["name"],state=expected_state)


if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("expected_udid", nargs="?")
    parser.add_argument("--candidates", type=Path)
    args = parser.parse_args()
    data = json.load(sys.stdin)
    if args.candidates:
        args.candidates.write_text(json.dumps(candidates(data), indent=2) + "\n", encoding="utf-8")
    try:
        selection = select(data, args.expected_udid)
    except (KeyError, ValueError) as exc:
        raise SystemExit(f"Simulator inventory rejected: {exc}") from None
    print(json.dumps(selection, indent=2))
