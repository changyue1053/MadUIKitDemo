"""Classify a local Gradle diagnostic; emit no log content, paths, IDs or snippets."""
import argparse
import json
import re
from pathlib import Path

TASK = re.compile(r"^(?:> Task (:[\w-]+(?::[\w-]+)+) FAILED|Execution failed for task '(?P<quoted>:[\w-]+(?::[\w-]+)+)'\.)\s*$")
ALLOWED = {
    ":composeApp:compileKotlinIosSimulatorArm64",
    ":composeApp:linkDebugFrameworkIosSimulatorArm64",
    ":composeApp:verifySdkCompile",
}
RULES = (
    ("unresolved-kotlin-reference", re.compile(r"^e:.*\bUnresolved reference\b", re.M)),
    ("kotlin-source-error", re.compile(r"^e:.*(?:\.kt:|\.kt\s*\()", re.M)),
    ("native-linker", re.compile(r"(?:^ld: |^Undefined symbols for architecture|^clang: error: linker command failed)", re.M)),
    ("apple-sdk-toolchain", re.compile(r"SDK .* cannot be located|xcrun: error:|unable to find utility", re.I)),
    ("native-toolchain-download", re.compile(r"(?:downloading kotlin/native|kotlin-native-prebuilt).*(?:failed|could not)", re.I)),
    ("public-dependency-resolution", re.compile(r"Could not (?:resolve|download|GET)|PKIX path building failed")),
)

def classify(log, code):
    if code == 0:
        return None, "passed"
    if code == 124:
        return None, "timeout"
    task = None
    for line in log.splitlines():
        match = TASK.fullmatch(line)
        if match:
            observed = match[1] or match["quoted"]
            task = observed if observed in ALLOWED else "unrecognized-failed-task"
            break
    kinds = [category for category, pattern in RULES if pattern.search(log)]
    return task, (kinds[0] if kinds else "unclassified")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("gate", choices=["ios-resolve", "ios-compile", "ios-framework"])
    parser.add_argument("code", type=int, choices=range(256))
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    task, category = classify(args.log.read_text(errors="replace"), args.code)
    print(json.dumps({"gate": args.gate, "exit": args.code, "firstFailedTask": task, "diagnosticCategory": category}, sort_keys=True))
