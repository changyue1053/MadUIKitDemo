"""Fail-closed selector for one documented Mac 26/iOS 26.4 iPhone 17 Pro."""
import json
import re
import sys

RUNTIME_PAIR=("com.apple.CoreSimulator.SimRuntime.iOS-26-4","26.4")
DEVICE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"


def select(data, expected_udid=None):
    runtime,=(r for r in data["runtimes"] if (r.get("identifier"),r.get("version")) == RUNTIME_PAIR and r.get("isAvailable") is True)
    build=runtime.get("buildversion")
    if not isinstance(build,str) or not re.fullmatch(r"[0-9]{2}[A-Z][0-9]+[a-z]?",build):
        raise ValueError("Missing or invalid installed simulator build identity")
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
    print(json.dumps(select(json.load(sys.stdin),sys.argv[1] if len(sys.argv)>1 else None),indent=2))
