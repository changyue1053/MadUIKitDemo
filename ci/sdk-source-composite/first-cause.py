"""Classify a bounded publisher failure without emitting any Gradle log data."""
from pathlib import Path
import json
import re
import sys

MAX=2*1024*1024
CATEGORIES=(
 ("dependency-transport",r"could not (?:get|head|download)|connection reset|read timed out|sslhandshakeexception|received status code (?:4\d\d|5\d\d)"),
 ("dependency-or-plugin-resolution",r"could not (?:resolve|find)|was not found in any of the following sources|no cached version"),
 ("jdk-sdk-or-toolchain",r"(?:sdk location not found|failed to find target with hash string|no matching toolchains|java_home is not set|unsupportedclassversionerror)"),
 ("local-filesystem-or-resource",r"(?:outofmemoryerror|java heap space|no space left on device|read-only file system|permission denied)"),
 ("compilation",r"(?:compilation error|compilation failed|compiler execution failed|error while compiling|kotlin compiler.*failed)"),
 ("publication",r"(?:failed to publish publication|could not publish|publication.*invalid)"),
)
COMPILES=re.compile(r"Execution failed for task '[^'\n]*:(?:compile(?:Release|Debug)?Kotlin|compileKotlinIos)[^'\n]*'\.")
CAUSAL=re.compile(r"(?ms)^\* What went wrong:\s*\n(.*?)(?=^\* (?:Try|Exception is|Get more help):|\Z)")


def classify(code,text,truncated=False):
    if code==0:return "passed"
    if code==124:return "bounded-timeout"
    if code>=128:return "process-terminated"
    m=CAUSAL.search(text)
    if not m:return "causal-block-not-observed" if not truncated else "bounded-log-window"
    block=m[1][:32768]
    # Pick earliest specific causal disclosure. Wrapper task headings alone do
    # not override a later dependency or tool failure.
    match=[]
    for order,(kind,pattern) in enumerate(CATEGORIES):
        if found:=re.search(pattern,block,re.I):
            match.append((found.start(),order,kind))
    if match:return min(match)[2]
    if COMPILES.search(block):return "compile-task-error-unclassified"
    return "first-cause-unclassified"


if __name__=="__main__":
    code=int(sys.argv[1])
    log=Path(sys.argv[2])
    with log.open("rb") as f: raw=f.read(MAX+1)
    print(json.dumps({"scope":"publisher first bounded causal category only",
        "publisherExit":code,"publisherCategory":classify(code,raw[:MAX].decode("utf-8","replace"),len(raw)>MAX)},
        sort_keys=True))
