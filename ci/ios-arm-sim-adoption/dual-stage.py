"""Compare actual same-run ARM64 publication bytes across both independent consumers."""
import hashlib
import json
from pathlib import Path
import re
import sys

SDK="19c8c1b1fbe75b7d6a6118fdab42048948de091b"
GROUP="com.mad.maduikit"
MODULES=("maduikit-components","maduikit-theme")
TARGET="iossimulatorarm64"
V="0.1.0-alpha01"
CASES=("books","typed-enabled","typed-disabled")

def need(ok,why):
    if not ok:raise ValueError(why)

def sha(p):
    with p.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()

def coord(m,target=True):
    return f"{GROUP}:{m}{'-'+TARGET if target else ''}:{V}"

def freeze(stage):
    need(stage.resolve(strict=True)==stage and stage.is_dir(),"Missing or linked stage")
    files={}
    for p in sorted(stage.rglob("*")):
        need(not p.is_symlink() and (p.is_dir() or p.is_file()),"Bad stage entry")
        if p.is_file():files[p.relative_to(stage).as_posix()]=sha(p)
    need(len(files)==130,"Unexpected ARM64 simulator only stage inventory")
    for path in files:
        if path.endswith((".md5",".sha1",".sha256",".sha512")):continue
        data=(stage/path).read_bytes()
        for algorithm in ("md5","sha1","sha256","sha512"):
            side=stage/(path+"."+algorithm)
            need(side.is_file() and side.read_text().strip().lower()==hashlib.new(algorithm,data).hexdigest(),
                 "Missing or incorrect exact staging sidecar")
    need(sum(name.endswith((".md5",".sha1",".sha256",".sha512")) for name in files)==104,
         "Incorrect exact staged sidecar inventory")
    leaves={}
    for m in MODULES:
        prefix=f"com/mad/maduikit/{m}-{TARGET}/{V}/{m}-{TARGET}-{V}"
        value=files[prefix+".klib"]
        meta=json.loads((stage/(prefix+".module")).read_text())
        variant,=[x for x in meta["variants"] if x["attributes"].get("org.gradle.usage")=="kotlin-api"
                  and x["attributes"].get("org.jetbrains.kotlin.native.target")=="ios_simulator_arm64"]
        item,=[f for f in variant["files"] if f["url"]==Path(prefix+".klib").name]
        need(item["sha256"]==value and item["size"]==(stage/(prefix+".klib")).stat().st_size,"Wrong staged leaf metadata")
        leaves[coord(m)]=value
    return dict(sdkPin=SDK,version=V,scope="own-run simulator-only Maven filesystem; no canonical comparison",
                stageFiles=len(files),sidecars=104,manifestSha256=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest(),
                klibShas=leaves)

def resolution(text,expected):
    rows={}
    for line in text.splitlines():
        if not line.startswith(f"Resolved {GROUP}:"):continue
        m=re.fullmatch(r"Resolved (com\.mad\.maduikit:[\w-]+:[\w.\-]+) sha256=([0-9a-f]{64}) variant=\{(.+)\}",line)
        need(m,"Malformed consumer report")
        coord_,hashed,attrs=m.groups()
        pairs=[x.split("=",1) for x in attrs.split(", ")]
        r=dict(pairs)
        need(len(r)==len(pairs) and r.get("org.jetbrains.kotlin.native.target")=="ios_simulator_arm64"
             and r.get("artifactType")=="org.jetbrains.kotlin.klib" and r.get("org.jetbrains.kotlin.platform.type")=="native",
             "Wrong consumer SDK target")
        need(coord_ not in rows,"Duplicate SDK resolution row")
        rows[coord_]=hashed
    need(rows==expected,"Consumer bytes do not match frozen own-run SDK stage")
    c,t=MODULES
    edges={f"{coord(c,False)} -> {coord(c)}",f"{coord(c)} -> {coord(t,False)}",f"{coord(t,False)} -> {coord(t)}"}
    need(edges.issubset(text.splitlines()),"No transitive theme proof")
    return rows

def validate(stage,before,reports):
    locked=json.loads(before.read_text())
    need(freeze(stage)==locked,"Stage drifted during consumer builds/tests")
    paths={k:reports/k/"composeApp/build/reports/sdk-adoption.txt" for k in CASES}
    need(all(p.is_file() and p.resolve()==p for p in paths.values()),"Missing or linked per-consumer resolution evidence")
    need(len({(p.stat().st_dev,p.stat().st_ino) for p in paths.values()})==3,"Aliased consumer resolution")
    return {k:dict(reportSha256=sha(p),klibShas=resolution(p.read_text(),locked["klibShas"])) for k,p in paths.items()}

if __name__=="__main__":
    stage=Path(sys.argv[1])
    if len(sys.argv)==2:
        print(json.dumps(freeze(stage),indent=2))
    elif len(sys.argv)==5:
        case=sys.argv[4]
        if case=="all":
            results=validate(stage,Path(sys.argv[2]),Path(sys.argv[3]))
        else:
            need(case in CASES,"Unexpected consumer case")
            prior=json.loads(Path(sys.argv[2]).read_text())
            need(freeze(stage)==prior,"Unexpected stage mutation before native execution")
            path=Path(sys.argv[3])/case/"composeApp/build/reports/sdk-adoption.txt"
            need(path.is_file() and path.resolve()==path,"Bad exact consumer report")
            results=dict(reportSha256=sha(path),klibShas=resolution(path.read_text(),prior["klibShas"]))
        print(json.dumps(results,indent=2))
