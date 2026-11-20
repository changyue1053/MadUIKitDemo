"""Record simulator platform, check upstream SDK source bytes, stage prebuilt framework."""
from pathlib import Path
import hashlib,json,re,shutil,sys
sdk,original,demo,framework,out=map(Path,sys.argv[1:6])
sdkver,head=sys.argv[6:]
platforms=re.findall(r"^\s*platform\s+(\S+)\s*$",(out/"framework-load-commands.txt").read_text(),re.M)
assert platforms and set(platforms)<={"7","IOSSIMULATOR"},platforms
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files=[p for p in original.rglob("*") if p.is_file() and ".git" not in p.parts]
assert files and all(sha(sdk/p.relative_to(original))==sha(p) for p in files)
assert (framework/"Headers/MadUIKitDemoShared.h").is_file()
dest=demo/"composeApp/build/xcode-frameworks/Debug"/("iphonesimulator"+sdkver)/framework.name
shutil.copytree(framework,dest)
hashes={str(p.relative_to(dest)):sha(p) for p in dest.rglob("*") if p.is_file()}
(demo/"prebuilt-framework.json").write_text(json.dumps(dict(sdkName="iphonesimulator"+sdkver,files=hashes),indent=2))
(out/"compile-receipt.json").write_text(json.dumps(dict(sdkPin="19c8c1b1fbe75b7d6a6118fdab42048948de091b",
    workflowCommit=head,unchangedSdkFiles=len(files),architecture="arm64",target="ios_simulator_arm64",
    platforms=sorted(set(platforms)),frameworkHashes=hashes,compileAndLink=True,runtimeClaim=False),indent=2)+"\n")
