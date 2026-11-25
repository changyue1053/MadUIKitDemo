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
        "stage-before","android-compile","ios-simulator-compile","stage-after","validate-bindings",
        "verified","scratch-cleanup-failed"}
TARGETS=("android","iossimulatorarm64")

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def bindings(w):
    before=w/"stage-before.json"; after=w/"stage-after.json"
    if before.read_bytes()!=after.read_bytes(): raise ValueError("stage mutated")
    stage=json.loads(before.read_text())
    if stage["version"]!=VERSION or len(stage["files"])!=250 or len(stage["leafs"])!=6:
        raise ValueError("unexpected stage shape")
    targets={}
    for target in TARGETS:
        names=[f"maduikit-{m}-{target}" for m in ("components","theme")]
        selected={}
        for line in (w/(target+".tsv")).read_text().splitlines():
            name,digest=line.split("\t")
            if name not in names or name in selected or HASH.fullmatch(digest) is None or stage["leafs"][name]["sha256"]!=digest:
                raise ValueError("wrong selected leaf")
            selected[name]=digest
        if set(selected)!=set(names): raise ValueError("incomplete optimized graph")
        targets[target]=selected
    return dict(stageSha256=sha(before),stageFileCount=250,allLeafCount=6,
                exactSelectedCompileLeaves=targets,sdkEdgesVerified=True,stageUnchanged=True)

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
                    scope="one synthetic same-job temporary Maven stage; Android and iOS ARM64 simulator compile only")
        if int(rc)==0 and gate=="verified":
            result.update(bindings(w));result["callerSha256"]=sha(w/"app/composeApp/src/commonMain/kotlin/StageCaller.kt")
        Path(out).write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    else:
        raise SystemExit("invalid receipt mode")
