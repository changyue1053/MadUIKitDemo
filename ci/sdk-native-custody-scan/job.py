"""Same-job source-native staging eligibility; no payload transfer."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys

import audit

PIN="cec44952263f528bb3775f0af63af51b4a04b621"
VER="0.1.0-alpha03-sdk-preview01"


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def observe(command, stage, filename):
    # Full structural manifests and any diagnostic trace remain under private scratch.
    with filename.open("xb") as out, filename.with_suffix(".err").open("xb") as err:
        return subprocess.run(command+[str(stage)],stdout=out,stderr=err,timeout=90).returncode==0


def drive(work, verify, observe_stage=observe, scanner=audit.validate):
    r={"mavenValidation":"not-run","scan":"not-run","stageEquality":"not-run",
       "transport":"not-authorized-no-capsule","stageManifestSha256":None,
       "findingCounts":{}}
    stage=work/"stage"
    if not stage.is_dir() or stage.is_symlink(): return r|{"mavenValidation":"stage-unavailable"}
    original=work/"manifest-before.json"
    mirror=work/"manifest-scan-anchor.json"
    final=work/"manifest-after.json"
    cmd=[sys.executable,str(verify)]
    if not observe_stage(cmd,stage,original):
        return r|{"mavenValidation":"failed"}
    r["mavenValidation"]="passed"
    mirror.write_bytes(original.read_bytes())
    # Scan checks every actual file against canonical before manifest snapshot.
    try:
        result=scanner("alpha03-job-local",stage,original,mirror,work/"sdk")
        r["scan"]=result["status"]
        # Audit reasons/roles are fixed literals; prevent accidental raw any future reason.
        findings=result["findings"]
        reasons=set(audit.PATTERNS)
        allowed={"aar","classes","klib","klib-ir-file-path-table","sources","root-metadata","empty-metadata","maven-text","checksum"}
        for k,v in findings.items():
            if ":" in k and k.split(":",1)[0] in allowed and k.split(":",1)[1] in reasons and type(v) is int and 0<v<=1000:
                r["findingCounts"][k]=v
            else:
                r["findingCounts"]["structural-or-unknown-refusal"]=1
        if (result["status"] not in {"blocked","scanner-eligible-not-authorized"} or
                (findings and result["status"]!="blocked")):
            r["scan"]="blocked-unclassified"
    except Exception:
        r["scan"]="blocked-unclassified"
    # This observation repeats Maven structural validation and full on-disk hashing,
    # not the build or six consumers. Changed stage overrides any scanner PASS.
    try: same=observe_stage(cmd,stage,final) and digest(original)==digest(final)==digest(mirror)
    except Exception: same=False
    r["stageEquality"]="unchanged" if same else "changed-or-unverified"
    if same:
        r["stageManifestSha256"]=digest(original)
    else:
        r["scan"]="blocked-stage-changed"
    return r


def main():
    work,output=map(Path,sys.argv[1:])
    parent=Path(os.environ["RUNNER_TEMP"]).resolve(strict=True)
    # All stage inputs were produced inside the dedicated one-job temp.
    if work.is_symlink() or work.resolve(strict=True).parent!=parent or not work.name.startswith("mad-custody-"):
        raise SystemExit(2)
    if output.is_symlink() or output.parent.resolve(strict=True)!=parent/"mad-custody-receipt":
        raise SystemExit(2)
    verify=Path(__file__).resolve().parents[1]/"sdk-native-preview-proof/verify-stage.py"
    r=drive(work,verify)
    for n in ("GITHUB_RUN_ID","GITHUB_RUN_ATTEMPT"):
        if not re.fullmatch(r"[0-9]{1,20}",os.environ.get(n,"")): raise SystemExit(2)
    if not re.fullmatch(r"[a-f0-9]{40}",os.environ.get("GITHUB_SHA","")): raise SystemExit(2)
    r|={"run":os.environ["GITHUB_RUN_ID"],"attempt":os.environ["GITHUB_RUN_ATTEMPT"],
        "demoCommit":os.environ["GITHUB_SHA"],"sdkCommit":PIN,"version":VER,
        "scope":"fresh same-run stage scan, not original stage identity, no binary or capsule export"}
    with output.open("x") as stream:
        json.dump(r,stream,sort_keys=True,indent=2); stream.write("\n")
    return 0 if (r["scan"],r["stageEquality"])==("scanner-eligible-not-authorized","unchanged") else 1


if __name__=="__main__":
    raise SystemExit(main())
