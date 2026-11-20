"""Check the exact generic build-for-testing products; export receipt, never binaries."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys


def need(condition,message):
    if not condition:
        raise ValueError(message)


def sha(p):
    with p.open("rb") as f:
        return hashlib.file_digest(f,"sha256").hexdigest()


CONFIG="Debug-iphonesimulator"
APP="MadUIKitDemo.app"
RUNNER="MadUIKitDemoUITests-Runner.app"
BUNDLE="MadUIKitDemoUITests.xctest"


def confined(path, root):
    need(path == path.resolve(strict=True) and path.is_relative_to(root), "Noncanonical/linked test product")
    return path


def declared(path, root, host=None):
    need(isinstance(path,str) and path and ".." not in Path(path).parts, "Unsafe XCTest path")
    if path.startswith("__TESTROOT__/"):
        candidate=root/path.removeprefix("__TESTROOT__/")
    elif path.startswith("__TESTHOST__/") and host is not None:
        candidate=host/path.removeprefix("__TESTHOST__/")
    else:
        # Some versions record canonical absolute build paths.
        need(path.startswith("/") and "__" not in path, "Unexpected XCTest path macro")
        candidate=Path(path)
    return confined(candidate,root)


def test_target(data):
    if "TestConfigurations" in data:
        rows=[t for plan in data["TestConfigurations"] if plan.get("IsEnabled",True)
              for t in plan["TestTargets"] if t.get("IsEnabled",True)]
        need(len(rows)==1,"Unexpected additional enabled test target")
        selected=[t for t in rows if t.get("BlueprintName")==BUNDLE.removesuffix(".xctest")]
    else:
        rows=[(k,v) for k,v in data.items() if isinstance(v,dict) and "TestBundlePath" in v]
        need(len(rows)==1,"Unexpected additional legacy test target")
        selected=[v for k,v in rows if k==BUNDLE.removesuffix(".xctest")]
    need(len(selected)==1, "Expected one exact configured UI test target")
    return selected[0]


def platform(binary):
    arch=subprocess.check_output(["xcrun","lipo","-archs",str(binary)],text=True).strip()
    loads=subprocess.check_output(["xcrun","otool","-l",str(binary)],text=True)
    platforms=re.findall(r"^\s*platform\s+(\S+)\s*$", loads, re.M)
    need(arch=="arm64" and platforms and set(platforms)<={"7","IOSSIMULATOR"},
         f"Wrong simulator architecture/platform: {binary.name}")
    return {"architecture":arch, "platform":7}


def info(bundle):
    metadata=bundle/"Info.plist"
    need(metadata.is_file() and not metadata.is_symlink() and metadata.resolve()==metadata, "Missing or linked bundle metadata")
    return plistlib.loads(metadata.read_bytes())


def inspect(root, observe=platform):
    root=root.absolute()
    need(root.is_dir() and root.resolve()==root,"Missing or linked product root")
    runfiles=sorted(root.glob("*.xctestrun"))
    need(len(runfiles)==1 and runfiles[0].is_file(),"Expected one xctestrun at Build/Products root")
    runfile=confined(runfiles[0],root)
    row=test_target(plistlib.loads(runfile.read_bytes()))
    target_app=declared(row["UITargetAppPath"],root)
    host=declared(row["TestHostPath"],root)
    # Accept Xcode's executable form as well as the .app directory form for TestHostPath.
    if host.is_file():
        need(host.name==info(host.parent)["CFBundleExecutable"], "Wrong XCTest host executable")
        host=host.parent
    test_bundle=declared(row["TestBundlePath"],root,host)
    need(target_app == root/CONFIG/APP and host == root/CONFIG/RUNNER and
         test_bundle == host/"PlugIns"/BUNDLE, "Test declaration and actual products do not match")
    records=[]
    approved=set()
    for bundle in (target_app,host,test_bundle):
        meta=info(bundle)
        exe=meta["CFBundleExecutable"]
        need(re.fullmatch(r"[A-Za-z0-9_.-]+",exe) and exe not in (".",".."),"Unsafe executable name")
        binary=confined(bundle/exe,root)
        need(binary.is_file() and binary not in approved,"Missing/duplicate test executable")
        approved.add(binary)
        records.append(dict(bundle=bundle.relative_to(root).as_posix(),bundleId=meta["CFBundleIdentifier"],
            executable=binary.relative_to(root).as_posix(),sha256=sha(binary),bytes=binary.stat().st_size,
            infoPlistSha256=sha(bundle/"Info.plist"),**observe(binary)))
    need(records[0]["bundleId"]=="dev.mad.adoption.ios","Wrong public test application identity")
    return dict(xctestrun={"path":runfile.relative_to(root).as_posix(),"sha256":sha(runfile)},
                verifiedProducts=records,runtime="not-run",publishedBinaries=False)


def main():
    root,out=map(Path,sys.argv[1:3])
    commit=sys.argv[3]
    need(re.fullmatch(r"[a-f0-9]{40}",commit) is not None,"Missing exact workflow commit")
    result=inspect(root)
    result.update(workflowCommit=commit,destination="generic/platform=iOS Simulator")
    with out.open("x",encoding="utf-8") as f:
        json.dump(result,f,indent=2)
        f.write("\n")


if __name__=="__main__":
    main()
