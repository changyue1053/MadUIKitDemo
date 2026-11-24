"""Verify an ephemeral framework within one runner, without exporting it."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import sys

NAME = "MadUIKitS1Adopter"
LIMITS = {NAME: 150_000_000, f"Headers/{NAME}.h": 400_000, "Modules/module.modulemap": 20_000, "Info.plist": 40_000}
HASH = re.compile(r"[0-9a-f]{64}")

def require(condition, message):
    if not condition:
        raise SystemExit(message)

def job_path(path):
    root = Path(os.environ["RUNNER_TEMP"]).resolve(strict=True)
    path = Path(path)
    resolved = path.resolve()
    require(path.is_absolute() and path == resolved and root in resolved.parents, "Input outside physical job temp")
    return resolved

def file_hash(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def inventory_files(directory):
    require(directory.name==f"{NAME}.framework" and directory.is_dir(), "Wrong local framework")
    found = list(directory.rglob("*"))
    require(all(not p.is_symlink() and (p.is_file() or p.is_dir()) for p in found), "Unsafe framework inventory")
    files = {p.relative_to(directory).as_posix(): p for p in found if p.is_file()}
    require(set(files)==set(LIMITS), "Unexpected local framework file list")
    return files

def size_receipt(directory):
    roles = {
        NAME: "static-archive",
        f"Headers/{NAME}.h": "generated-header",
        "Modules/module.modulemap": "module-map",
        "Info.plist": "framework-plist",
    }
    result = {}
    for name, path in inventory_files(directory).items():
        size = path.stat().st_size
        limit = LIMITS[name]
        status = "zero" if size == 0 else "over-cap" if size > limit else "within-cap"
        result[roles[name]] = dict(bytes=size, capBytes=limit, status=status)
    return dict(roles=result, allWithinExistingLimits=all(v["status"] == "within-cap" for v in result.values()))

def inventory(directory):
    files = inventory_files(directory)
    require(all(0<p.stat().st_size<=LIMITS[n] for n,p in files.items()), "Unexpected local framework size")
    with files[NAME].open("rb") as f:
        require(f.read(8)==b"!<arch>\n", "Static archive required")
    require(b"fixtureViewController" in files[f"Headers/{NAME}.h"].read_bytes(), "Missing fixture controller export")
    require(b"framework module "+NAME.encode() in files["Modules/module.modulemap"].read_bytes(), "Wrong module")
    require(plistlib.loads(files["Info.plist"].read_bytes()).get("CFBundleExecutable")==NAME, "Wrong plist executable")
    return {k:file_hash(v) for k,v in files.items()}

def no_active_guest(doc):
    devices=doc.get("devices")
    require(isinstance(devices,dict) and devices, "Missing stock guest inventory")
    require(all(isinstance(rows,list) for rows in devices.values()), "Invalid guest inventory")
    entries = [row for rows in devices.values() for row in rows]
    require(entries and all(isinstance(row, dict) and row.get("state")=="Shutdown" for row in entries),
            "Guest not quiescent; refuse to boot or shut it down")

def handle():
    mode=sys.argv[1]
    if mode=="measure":
        require(len(sys.argv)==3,"Unexpected diagnostic arguments")
        print(json.dumps(size_receipt(job_path(sys.argv[2])),sort_keys=True,indent=2))
        return
    if mode=="check-guests":
        require(len(sys.argv)==2,"Unexpected guest arguments")
        no_active_guest(json.load(sys.stdin))
        return
    require((mode=="record" and len(sys.argv)==8) or (mode=="verify" and len(sys.argv)==4),"Unexpected provenance arguments")
    directory, proof = map(job_path,sys.argv[2:4])
    fingerprints = inventory(directory)
    fixed=dict(commit=os.environ["GITHUB_SHA"],run=os.environ["GITHUB_RUN_ID"],attempt=os.environ["GITHUB_RUN_ATTEMPT"],
               sdkCommit="19c8c1b1fbe75b7d6a6118fdab42048948de091b",target="ios_simulator_arm64",syntheticOnly=True,
               frameworkCustody="same-job-temp-never-exported")
    require(re.fullmatch(r"[0-9a-f]{40}",fixed["commit"]) and fixed["run"].isdecimal() and fixed["attempt"].isdecimal(),"Invalid job binding")
    keys=("binarySha256","graphSha256","callerSha256","stageSha256")
    if mode=="record":
        values=dict(zip(keys,sys.argv[4:]))
    else:
        require(proof.is_file() and 0<proof.stat().st_size<=8192,"Missing local provenance")
        original=json.loads(proof.read_text())
        require(set(original)==set(fixed)|set(keys)|{"files"} and all(original.get(k)==v for k,v in fixed.items()),"Wrong local framework binding")
        require(original["files"]==fingerprints,"Framework inventory drifted")
        values={k:original.get(k) for k in keys}
    require(all(isinstance(value,str) and HASH.fullmatch(value) for value in values.values()),"Missing provenance fingerprint")
    require(values["binarySha256"]==fingerprints[NAME],"Framework differs from verified link receipt")
    if mode=="record":
        with proof.open("x") as f:
            json.dump(dict(fixed,**values,files=fingerprints),f,indent=2,sort_keys=True)

if __name__=="__main__":
    try:
        handle()
    except (IndexError, OSError, TypeError, ValueError, KeyError, plistlib.InvalidFileException):
        raise SystemExit("Same-job framework validation failed") from None
