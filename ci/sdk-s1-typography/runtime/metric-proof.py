"""Same-job synthetic metric receipt; allowlisted data, one original PNG, no binaries."""
import hashlib,json,os,re,struct,sys
from pathlib import Path

KOTLIN={"composeMetrics":"composeApp/src/iosMain/kotlin/TypographyMetrics.kt",
        "composeController":"composeApp/src/iosMain/kotlin/FixtureViewController.kt",
        "fixtureDependencies":"composeApp/build.gradle.kts"}
SWIFT={"swiftLaunch":"DemoApp.swift","swiftMetricsTest":"BookFilterUITests.swift"}
IDS={"composeMetrics","composeController","fixtureDependencies","swiftLaunch","swiftMetricsTest"}
NAME="S1-typography-metrics-original"
SIG=b"\x89PNG\r\n\x1a\n"
TEST="MadUIKitDemoUITests/TypographyMetricsUITests/testSyntheticNativeMetrics"
def need(value, reason):
    if not value: raise SystemExit(reason)
def sha(value): return hashlib.sha256(value).hexdigest()
def job_path(path):
    root=Path(os.environ["RUNNER_TEMP"]).resolve(strict=True)
    path=Path(path)
    need(path==path.resolve() and root in path.parents,"Metric data outside actual job temp")
    return path
def read(path, limit):
    need(path==path.resolve() and not path.is_symlink() and path.is_file() and 0<path.stat().st_size<=limit,
         "Unexpected metric source or attachment")
    return path.read_bytes()
def sources(adopter, host):
    trusted=Path(__file__).resolve().parent
    expected_adopter=trusted.parent/"ui-adopter"
    expected_host=trusted/"iosApp"
    def match(prefixes, actual, expected):
        into={}
        for role,name in prefixes.items():
            into[role]=sha(read(expected/name,100_000))
            need(into[role]==sha(read(actual/name,100_000)), "Metric fixture source mismatch")
        return into
    return dict(match(KOTLIN,job_path(adopter),expected_adopter),**match(SWIFT,host,expected_host))
def receipt(proof, hashes):
    need(set(hashes)==IDS and all(re.fullmatch(r"[0-9a-f]{64}",s) for s in hashes.values()),"Unexpected fixture identities")
    doc=json.loads(read(job_path(proof),8192))
    need(doc.get("frameworkCustody")=="same-job-temp-never-exported" and doc.get("syntheticOnly") is True and
         doc.get("commit")==os.environ["GITHUB_SHA"] and doc.get("run")==os.environ["GITHUB_RUN_ID"] and
         doc.get("attempt")==os.environ["GITHUB_RUN_ATTEMPT"],"Mismatch in synthetic framework provenance")
    fp=("binarySha256","stageSha256","graphSha256","callerSha256")
    need(all(isinstance(doc.get(k),str) and re.fullmatch(r"[0-9a-f]{64}",doc[k]) for k in fp),
         "Missing exact linked input fingerprint")
    return {"sourceSha256":hashes,"linkedFrameworkReceiptSha256":sha(read(job_path(proof),8192)),
            "framework":{k:doc[k] for k in (*fp,"commit","run","attempt","frameworkCustody")}}
def walk(x):
    if isinstance(x,dict):
        if "exportedFileName" in x: yield x
        for v in x.values(): yield from walk(v)
    elif isinstance(x,list):
        for v in x: yield from walk(v)
def attachments(root, stem, ext, limit):
    entries=list(walk(json.loads(read(root/"manifest.json",100_000))))
    match=[e for e in entries if re.fullmatch(re.escape(stem)+r"(?:_[A-Za-z0-9_-]+)?\."+ext,e.get("suggestedHumanReadableName",""))]
    need(len(match)==1,"Missing or ambiguous exact metric attachment")
    relative=match[0]["exportedFileName"]
    need(isinstance(relative,str) and re.fullmatch(r"[A-Za-z0-9_.-]+\."+ext,relative),"Unexpected metric attachment path")
    return read(root/relative,limit)
def accept(summary, path, output, proof, bindings):
    summary,path,output,proof,bindings=map(job_path,(summary,path,output,proof,bindings))
    s=json.loads(read(summary,100_000))
    need(s.get("result")=="Passed" and s.get("totalTestCount")==1 and s.get("passedTests")==1 and s.get("failedTests")==0,
         "Exact single metric XCTest did not pass")
    b=json.loads(read(bindings,8192))
    need(b==receipt(proof,b["sourceSha256"]), "Metric sources not bound to this framework")
    m=json.loads(attachments(path,"S1-typography-metric-values","json",8192))
    required={"density","tokenPx","gapsPx","scopedGlyphPx","outsideGlyphPx","scopedMatchesRaw","outsideMatchesRaw",
              "unchangedReferenceMatches","providerDisabledMatchesBaseline","wrongProviderRejected"}
    need(set(m)==required and type(m["density"]) in (float,int) and abs(m["density"]-3)<.01 and
         type(m["tokenPx"]) is int and m["tokenPx"]==24 and type(m["gapsPx"]) is list and
         all(type(v) is int for v in m["gapsPx"]) and m["gapsPx"]==[24,21,8],
         "Wrong actual Compose geometry")
    for k in ("scopedGlyphPx","outsideGlyphPx"):
        need(isinstance(m[k],list) and len(m[k])==2 and all(type(n) is int and 1<n<=1206 for n in m[k]),"Invalid glyph extents")
    need(m["scopedGlyphPx"][1]-m["outsideGlyphPx"][1]>=3 and
         all(m[k] is True for k in required if k.endswith("MatchesRaw") or k.endswith("Matches") or
             k in {"providerDisabledMatchesBaseline","wrongProviderRejected"}),"Missing glyph control result")
    png=attachments(path,NAME,"png",12_000_000)
    need(len(png)>=33 and png.startswith(SIG) and png[8:16]==b"\0\0\0\rIHDR" and
         struct.unpack(">II",png[16:24])==(1206,2622),"Wrong metric PNG dimensions or header")
    output.joinpath(NAME+".png").write_bytes(png)
    output.joinpath("native-metrics.json").write_text(json.dumps(dict(scope="synthetic iOS metrics only",test=TEST,
      nativeMetrics=m,measurementImageSha256=sha(png),provenance=b),sort_keys=True,indent=2)+"\n")
def main():
    cmd,*args=sys.argv[1:]
    if cmd=="accept" and len(args)==5: accept(*args); return
    need(cmd in ("bind","verify") and len(args)==4,"Unexpected metric proof arguments")
    adopter, host, proof, output=map(Path,args)
    doc=receipt(proof,sources(adopter,host))
    output=job_path(output)
    if cmd=="bind":
        with output.open("x") as f: json.dump(doc,f,sort_keys=True,indent=2)
    else:
        need(json.loads(read(output,8192))==doc,"Metric proof source binding drift")
if __name__=="__main__":
    try: main()
    except (OSError,ValueError,TypeError,KeyError,AttributeError): raise SystemExit("Metric proof validation failed") from None
