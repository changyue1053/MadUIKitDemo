"""Validate one exact Books XCTest attachment, then atomically accept PNG and receipt."""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
from tempfile import TemporaryDirectory

NAME="Independent-iOS-Arm64Simulator-Books"
UUID=r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"
ATTACHMENT=re.compile(NAME + r"(?:_[0-9]+)?(?:_" + UUID + r")?(?:\.png)?")
LIMIT=15_000_000


def need(ok, reason):
    if not ok:
        raise ValueError(reason)


def walk(x):
    if isinstance(x,dict):
        if "exportedFileName" in x: yield x
        else:
            for v in x.values(): yield from walk(v)
    elif isinstance(x,list):
        for v in x: yield from walk(v)


def read_attachment(root, file):
    need(isinstance(file,str) and re.fullmatch(r"[A-Za-z0-9_.-]+\.png",file),"Unexpected attachment filename")
    path=root/file
    need(path.resolve(strict=True)==path and not path.is_symlink(),"Linked attachment")
    need(stat.S_ISREG(path.lstat().st_mode),"Nonregular attachment")
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,"rb") as stream:
        meta=os.fstat(stream.fileno())
        need(stat.S_ISREG(meta.st_mode) and 8 < meta.st_size <= LIMIT,"Invalid attachment file size/type")
        payload=stream.read(LIMIT+1)
        need(len(payload)==meta.st_size and payload.startswith(b"\x89PNG\r\n\x1a\n"),"Invalid attachment payload")
        return payload


def inspect_frame(path, decoder):
    result=subprocess.run([str(decoder),str(path),"books"],text=True,capture_output=True,
                          check=True,timeout=45)
    return json.loads(result.stdout)


def accept(out, src, decoder, inspect=inspect_frame):
    out,src=out.absolute(),src.absolute()
    need(out.resolve(strict=True)==out and src.resolve(strict=True)==src, "Linked output/attachment root")
    accepted=out/"accepted-runtime"
    need(not os.path.lexists(accepted),"Accepted output already exists")
    summary=json.loads((out/"test-summary.json").read_text())
    need(summary["result"]=="Passed" and summary["passedTests"]==1 and summary["failedTests"]==0
         and summary["totalTestCount"]==1,"Exact single Books XCTest did not pass")
    selected=[v for v in walk(json.loads((src/"manifest.json").read_text()))
              if ATTACHMENT.fullmatch(v.get("suggestedHumanReadableName",""))]
    need(len(selected)==1,"Missing or ambiguous exact Books attachment")
    payload=read_attachment(src,selected[0]["exportedFileName"])
    with TemporaryDirectory(prefix=".validate-books-",dir=out) as temporary:
        t=Path(temporary)
        pending=t/"pair";pending.mkdir()
        png=pending/(NAME+".png");png.write_bytes(payload)
        witness=inspect(png,decoder)
        need(witness.get("profile")=="books" and witness.get("decodedPNG") is True
             and witness.get("nonblankCheck") is True and (witness.get("width"),witness.get("height"))==(1206,2622),
             "Apple Books PNG decode/dimension/profile gate failed")
        receipt=dict(runtime="passed",test="single launch with exact public Books labels asserted",
                     screenshotSha256=hashlib.sha256(payload).hexdigest(),screenshotBytes=len(payload),screen=witness)
        (pending/"runtime.json").write_text(json.dumps(receipt,indent=2)+"\n")
        need(not os.path.lexists(accepted),"Accepted output appeared during validation")
        pending.rename(accepted)
    return receipt


if __name__=="__main__":
    accept(*map(Path,sys.argv[1:]))
