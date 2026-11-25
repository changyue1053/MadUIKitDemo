from pathlib import Path
import hashlib
import json
import os
import re
import sys

PIN="99d7c390c718c1d115b491c8de3d64de443bad7b"
VERSION="0.1.0-alpha28-sdk-preview01"
HASH=re.compile(r"[0-9a-f]{64}")
STAGES={"pin","host-profile","stock-java","stock-xcode","stock-sdk36","exact-source","publish",
        "stage-before","disk-before-producer","stage-after","validate-bindings",
        "verified","scratch-cleanup-failed"}
TARGETS=("android","iossimulatorarm64")
APPS={
    "atlas":("AtlasTransfer.kt","625246eedcfade82d42cc81d72f257744b5635deae5379c716a214d657632167"),
    "orchid":("OrchidCatalog.kt","ad7a18e36d443f596ed1c2b7a74f74a900dd575f2b33ddd8854db7e7aee1678a"),
}
STAGES.update(f"{app}-{gate}" for app in APPS for gate in ("disk","android-compile","ios-simulator-compile"))

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def bindings(w):
    before=w/"stage-before.json"; after=w/"stage-after.json"
    if before.read_bytes()!=after.read_bytes(): raise ValueError("stage mutated")
    stage=json.loads(before.read_text())
    if stage["version"]!=VERSION or len(stage["files"])!=250 or len(stage["leafs"])!=6:
        raise ValueError("unexpected stage shape")
    adoption={}
    for app,(filename,expected) in APPS.items():
        caller=w/app/"composeApp/src/commonMain/kotlin"/filename
        if sha(caller)!=expected:
            raise ValueError("unexpected adopter source")
        targets={}
        for target in TARGETS:
            names=[f"maduikit-{m}-{target}" for m in ("components","theme")]
            selected={}
            for line in (w/f"{app}-{target}.tsv").read_text().splitlines():
                name,digest=line.split("\t")
                if name not in names or name in selected or HASH.fullmatch(digest) is None or stage["leafs"][name]["sha256"]!=digest:
                    raise ValueError("wrong selected leaf")
                selected[name]=digest
            if set(selected)!=set(names):
                raise ValueError("incomplete optimized graph")
            targets[target]=selected
        adoption[app]=dict(sourceSha256=expected,exactSelectedCompileLeaves=targets)
    return dict(stageSha256=sha(before),stageFileCount=250,allLeafCount=6,
                adopters=adoption,sdkEdgesVerified=True,stageUnchanged=True)

if __name__=="__main__":
    mode,*args=sys.argv[1:]
    if mode=="qualify":
        bindings(Path(args[0]))
    elif mode=="emit":
        work,out,rc,gate=args
        if gate not in STAGES: raise SystemExit("unknown receipt checkpoint")
        demo=os.environ["GITHUB_SHA"]; run=os.environ["GITHUB_RUN_ID"]; attempt=os.environ["GITHUB_RUN_ATTEMPT"]
        if not re.fullmatch(r"[0-9a-f]{40}",demo) or not all(re.fullmatch(r"[0-9]{1,20}",v) for v in (run,attempt)):
            raise SystemExit("invalid run binding")
        w=Path(work)
        result=dict(demo=demo,run=run,attempt=attempt,sdk=PIN,version=VERSION,exit=int(rc),gate=gate,
                    scope="one official-module same-job temporary alpha28 stage; two independent synthetic consumer libraries; Android and iOS ARM64 simulator compile only")
        if int(rc)==0 and gate=="verified":
            result.update(bindings(w))
        Path(out).write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    else:
        raise SystemExit("invalid receipt mode")
