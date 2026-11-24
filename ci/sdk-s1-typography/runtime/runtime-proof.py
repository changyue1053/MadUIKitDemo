import hashlib,json,re,sys
from pathlib import Path

summary, attachments, output, transfer = map(Path,sys.argv[1:])
s=json.loads(summary.read_text())
if not (s["result"]=="Passed" and s["totalTestCount"]==1 and s["passedTests"]==1 and s["failedTests"]==0):
    raise SystemExit("Exact one XCTest must pass")
def walk(x):
    if isinstance(x,dict):
        if "exportedFileName" in x: yield x
        for v in x.values(): yield from walk(v)
    elif isinstance(x,list):
        for v in x: yield from walk(v)
manifest=list(walk(json.loads((attachments/"manifest.json").read_text())))
hashes={}
originals={}
for name in ("S1-alpha09-gallery-before","S1-alpha09-gallery-after"):
    selected=[e for e in manifest if re.fullmatch(re.escape(name)+r"(?:_[A-Za-z0-9_-]+)?\.png",e.get("suggestedHumanReadableName",""))]
    if len(selected)!=1: raise SystemExit("Missing or ambiguous exact original screenshot")
    filename=selected[0]["exportedFileName"]
    if not isinstance(filename,str) or not re.fullmatch(r"[A-Za-z0-9_.-]+\.png",filename): raise SystemExit("Invalid export path")
    p=attachments/filename
    if p.is_symlink() or p.resolve()!=p or not p.is_file() or not 8<p.stat().st_size<=12_000_000: raise SystemExit("Invalid screenshot file")
    data=p.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"): raise SystemExit("No original PNG")
    originals[name]=data
    hashes[name]=hashlib.sha256(data).hexdigest()
if len(set(hashes.values()))!=2: raise SystemExit("Screenshots did not change")
for name, data in originals.items():
    (output/(name+".png")).write_bytes(data)
receipt=dict(foundation=dict(palette="light/dark/brand/restored light; rendered sRGB", divider="default 1dp and explicit 3dp; measured 3/9px at density 3"),runtime="passed",scope="synthetic iOS simulator only; not S1 complete",selector="unique tagged labels, actual rendered accent colors and measured divider height",nativeInteraction="radio Online to Offline to Online to Offline with selected re-tap no-op",screenshots=hashes,framework=json.loads(transfer.read_text()))
(output/"runtime.json").write_text(json.dumps(receipt,sort_keys=True,indent=2)+"\n")
