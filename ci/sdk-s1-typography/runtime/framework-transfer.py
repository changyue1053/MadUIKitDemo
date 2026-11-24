"""Transport only the audited flat synthetic Kotlin/Native static framework."""
import argparse, hashlib, json, plistlib, re, stat, zipfile
from pathlib import Path

NAME="MadUIKitS1Adopter"
ALLOWED = {NAME, f"Headers/{NAME}.h", "Modules/module.modulemap", "Info.plist"}
LIMITS = {NAME: 150_000_000, f"Headers/{NAME}.h": 400_000, "Modules/module.modulemap": 20_000, "Info.plist": 40_000}
SHA=re.compile(r"[0-9a-f]{64}")
PRIVATE_MARKERS=re.compile(rb"/Users/(?!runner(?:/|$))[^\x00\s]+|/workspace/(?:scratch|shared)/|gh[pousr]_[A-Za-z0-9]{20,}|BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY", re.I)

def require(ok, reason):
    if not ok: raise SystemExit(reason)
def digest(b): return hashlib.sha256(b).hexdigest()
def scan(items):
    require(set(items)==ALLOWED, "Unexpected framework inventory")
    for n,b in items.items():
        require(0<len(b)<=LIMITS[n], "Framework member invalid size")
        require(PRIVATE_MARKERS.search(b) is None, "Unexpected sensitive marker in framework")
    require(items[NAME].startswith(b"!<arch>\n"), "Static archive required")
    require(b"fixtureViewController" in items[f"Headers/{NAME}.h"], "Synthetic controller not exported")
    require(b'framework module '+NAME.encode() in items["Modules/module.modulemap"], "Unexpected module")
    require(plistlib.loads(items["Info.plist"]).get("CFBundleExecutable")==NAME, "Wrong framework plist executable")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("mode",choices=["pack","unpack"])
    p.add_argument("framework",type=Path)
    p.add_argument("archive",type=Path)
    p.add_argument("identity",type=Path)
    p.add_argument("commit")
    p.add_argument("run")
    p.add_argument("attempt")
    p.add_argument("--binary-sha")
    p.add_argument("--graph-sha")
    p.add_argument("--caller-sha")
    p.add_argument("--stage-sha")
    a=p.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}",a.commit) and a.run.isdecimal() and a.attempt.isdecimal(), "Bad run binding")
    fixed={"commit":a.commit,"run":a.run,"attempt":a.attempt,"sdkCommit":"19c8c1b1fbe75b7d6a6118fdab42048948de091b","target":"ios_simulator_arm64","syntheticOnly":True}
    def fingerprints(doc):
        require(all(isinstance(doc.get(k),str) and SHA.fullmatch(doc[k]) for k in ("binarySha256","graphSha256","callerSha256","stageSha256")), "Missing provenance hash")
    if a.mode=="pack":
        paths=list(a.framework.rglob("*"))
        require(a.framework.is_dir() and not a.framework.is_symlink() and all(not x.is_symlink() and (x.is_file() or x.is_dir()) for x in paths), "Invalid framework member kind")
        items={x.relative_to(a.framework).as_posix():x.read_bytes() for x in paths if x.is_file()}
        scan(items); require(digest(items[NAME])==a.binary_sha, "Framework differs from link receipt")
        doc=dict(fixed,binarySha256=a.binary_sha,graphSha256=a.graph_sha,callerSha256=a.caller_sha,stageSha256=a.stage_sha)
        fingerprints(doc)
        with zipfile.ZipFile(a.archive,"x",compression=zipfile.ZIP_DEFLATED) as z:
            for k,v in sorted(items.items()): z.writestr(k,v)
        doc.update(archiveSha256=digest(a.archive.read_bytes()),files={k:digest(v) for k,v in sorted(items.items())})
        a.identity.write_text(json.dumps(doc,sort_keys=True,indent=2)+"\n")
    else:
        require(a.archive.stat().st_size <= 155_000_000 and a.identity.stat().st_size <= 8192,"Transfer exceeds limits")
        doc=json.loads(a.identity.read_text())
        require(all(doc.get(k)==v for k,v in fixed.items()), "Wrong producer identity")
        fingerprints(doc); require(doc["archiveSha256"]==digest(a.archive.read_bytes()), "Transport digest mismatch")
        with zipfile.ZipFile(a.archive) as z:
            names=z.namelist()
            require(len(names)==len(ALLOWED) and set(names)==ALLOWED,"Unexpected ZIP members")
            require(all(0<x.file_size<=LIMITS[x.filename] and stat.S_IFMT(x.external_attr>>16) in (0,stat.S_IFREG) for x in z.infolist()),"Invalid ZIP member size/type")
            items={k:z.read(k) for k in names}
        scan(items)
        require(doc["files"]=={k:digest(v) for k,v in items.items()} and digest(items[NAME])==doc["binarySha256"],"Member digest mismatch")
        a.framework.mkdir()
        for k,v in items.items():
            target=a.framework/k; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(v)

if __name__=="__main__": main()
