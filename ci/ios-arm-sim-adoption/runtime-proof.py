"""Require separate ARMSim XCTest/attachment evidence, never manufacture a screenshot."""
from pathlib import Path
import hashlib,json,re,shutil,sys
mode=sys.argv[1]
if mode=="platform":
    platforms=re.findall(r"^\s*platform\s+(\S+)\s*$",Path(sys.argv[2]).read_text(),re.M)
    assert platforms and set(platforms)<={"7","IOSSIMULATOR"},platforms
    sys.exit(0)
assert mode=="passed"
out,src=map(Path,sys.argv[2:])
summary=json.loads((out/"test-summary.json").read_text())
assert summary["result"]=="Passed" and summary["passedTests"]==1 and summary["failedTests"]==0
def walk(x):
    if isinstance(x,dict):
        if "exportedFileName" in x: yield x
        else:
            for v in x.values():yield from walk(v)
    elif isinstance(x,list):
        for v in x:yield from walk(v)
item,=(v for v in walk(json.loads((src/"manifest.json").read_text()))
       if v.get("suggestedHumanReadableName","").startswith("Independent-iOS-Arm64Simulator-Books"))
name=item["exportedFileName"]
assert Path(name).name==name and name.endswith(".png")
png=out/"Independent-iOS-Arm64Simulator-Books.png"
shutil.copyfile(src/name,png)
assert png.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
(out/"runtime.json").write_text(json.dumps(dict(runtime="passed",test="single launch and public label assertions",
    screenshotSha256=hashlib.sha256(png.read_bytes()).hexdigest()),indent=2)+"\n")
