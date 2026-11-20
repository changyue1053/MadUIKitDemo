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


def accept(out, src, decoder, inspect=inspect_frame, variant="books", log=None):
    need(variant in ("books","typed-enabled","typed-disabled"),"Unsupported app state")
    name=NAME if variant=="books" else "Typed-after"
    screen_name=NAME if variant=="books" else variant+"-after"
    pattern=re.compile(name + r"(?:_[0-9]+)?(?:_" + UUID + r")?(?:\.png)?")
    if variant!="books":
        need(log and "Launch dev.mad.adoption.ios.typedfilter" in log
             and "Test Case '-[MadUIKitTypedFilterUITests.TypedFilterUITests testGeneratedBinding]' passed" in log
             and len(re.findall(r"^\s*t =\s*[0-9.]+s\s+Tap ",log,re.M))==1,
             "Missing exact typed XCUITest launch and single physical tap trace")
    out,src=out.absolute(),src.absolute()
    need(out.resolve(strict=True)==out and src.resolve(strict=True)==src, "Linked output/attachment root")
    accepted=out/"accepted-runtime"
    need(not os.path.lexists(accepted),"Accepted output already exists")
    summary=json.loads((out/"test-summary.json").read_text())
    need(summary["result"]=="Passed" and summary["passedTests"]==1 and summary["failedTests"]==0
         and summary["totalTestCount"]==1,"Exact single Books XCTest did not pass")
    selected=[v for v in walk(json.loads((src/"manifest.json").read_text()))
              if pattern.fullmatch(v.get("suggestedHumanReadableName",""))]
    need(len(selected)==1,"Missing or ambiguous exact Books attachment")
    payload=read_attachment(src,selected[0]["exportedFileName"])
    with TemporaryDirectory(prefix=".validate-books-",dir=out) as temporary:
        t=Path(temporary)
        pending=t/"pair";pending.mkdir()
        png=pending/(screen_name+".png");png.write_bytes(payload)
        witness=inspect(png,decoder)
        need(witness.get("profile")=="books" and witness.get("decodedPNG") is True
             and witness.get("nonblankCheck") is True and (witness.get("width"),witness.get("height"))==(1206,2622),
             "Apple Books PNG decode/dimension/profile gate failed")
        receipt=dict(runtime="passed",test=("single launch with exact public Books labels asserted" if variant=="books"
                         else "single distinct public typed XCUITest with state-specific callback assertions"),
                     variant=variant,expectedCallbacks=(None if variant=="books" else int(variant=="typed-enabled")),
                     screenshotSha256=hashlib.sha256(payload).hexdigest(),screenshotBytes=len(payload),screen=witness)
        (pending/"runtime.json").write_text(json.dumps(receipt,indent=2)+"\n")
        need(not os.path.lexists(accepted),"Accepted output appeared during validation")
        pending.rename(accepted)
    return receipt


if __name__=="__main__":
    if len(sys.argv)==4:
        accept(*map(Path,sys.argv[1:]))
    else:
        accept(*map(Path,sys.argv[1:4]),variant=sys.argv[4],log=Path(sys.argv[5]).read_text())
