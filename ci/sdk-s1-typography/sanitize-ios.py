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
# Standard log prefixes may be added by the Kotlin/Native driver.
PREFIX = r"(?im)^\s*(?:(?:[ewi]:|\[ERROR\]|error:|warning:)\s*)*"
RULES = (
    ("unresolved-kotlin-reference", re.compile(PREFIX + r"e:.*\bUnresolved reference\b")),
    ("kotlin-source-error", re.compile(PREFIX + r"e:.*(?:\.kt:|\.kt\s*\()")),
    ("out-of-memory", re.compile(r"(?im)\b(?:java\.lang\.OutOfMemoryError|GC overhead limit exceeded|Java heap space|LLVM ERROR: out of memory|std::bad_alloc|unable to create (?:new )?native thread|Native memory allocation \(mmap\) failed|Direct buffer memory)\b")),
    ("native-linker", re.compile(PREFIX + r"(?:ld:|Undefined symbols for architecture|clang(?:\+\+)?: error: linker command failed)")),
    ("apple-sdk-toolchain", re.compile(PREFIX + r"(?:xcrun: error:|xcode-select: error:|SDK\b.*\b(?:cannot be located|not found|could not be found)|unable to find utility)")),
    ("native-compiler", re.compile(PREFIX + r"(?:LLVM ERROR:|Konan compilation failed|IrLinkageError\b)")),
    ("tool-process-exit", re.compile(r"(?im)(?:\bProcess\b[^\n]{0,350}\b(?:finished with non-zero exit value|exited with (?:code|status))\b|\bExternal tool execution failed\b)")),
    ("native-toolchain-download", re.compile(r"(?im)(?:downloading kotlin/native|kotlin-native-prebuilt)[^\n]*(?:failed|could not)")),
    ("public-dependency-resolution", re.compile(r"(?im)(?:Could not (?:resolve|download|GET)|PKIX path building failed)")),
)
# Intentionally map only exact vetted class names to safe tokens. Unknown exceptions
# may embed arbitrary identifiers and are never exported.
CAUSE = re.compile(r"(?m)^\s*Caused by: ([A-Za-z0-9_.$]+)(?=[:\s]|$)")
CAUSES = {
    "java.lang.OutOfMemoryError": "jvm-out-of-memory",
    "org.gradle.process.internal.ExecException": "gradle-tool-exec",
    "org.jetbrains.kotlin.konan.KonanExternalToolFailure": "konan-tool-exec",
    "org.jetbrains.kotlin.konan.KonanCompilationException": "konan-compilation",
    "org.gradle.internal.resolve.ModuleVersionResolveException": "gradle-dependency-resolution",
}
CAUSE_CATEGORY = {
    "jvm-out-of-memory": "out-of-memory",
    "gradle-tool-exec": "tool-process-exit",
    "konan-tool-exec": "tool-process-exit",
    "konan-compilation": "native-compiler",
    "gradle-dependency-resolution": "public-dependency-resolution",
}

def classify(log, code):
    if code in (0, 124):
        return None, "passed" if code == 0 else "timeout", [], []
    task = None
    for line in log.splitlines():
        match = TASK.fullmatch(line)
        if match:
            observed = match[1] or match["quoted"]
            task = observed if observed in ALLOWED else "unrecognized-failed-task"
            break
    causes = list(dict.fromkeys(CAUSES[name] for name in CAUSE.findall(log) if name in CAUSES))
    kinds = set(category for category, pattern in RULES if pattern.search(log))
    kinds.update(CAUSE_CATEGORY[cause] for cause in causes)
    if "unresolved-kotlin-reference" in kinds:
        kinds.discard("kotlin-source-error")
    # Generic wrappers are only fallback categories when specific evidence exists.
    primary = kinds - {"tool-process-exit", "native-compiler"}
    if not primary:
        primary = kinds
    category = next(iter(primary)) if len(primary) == 1 else ("ambiguous" if primary else "unclassified")
    return task, category, sorted(kinds), causes

HEAP_PROOF = re.compile(r"(?m)^MAD_S1_EFFECTIVE_LINK_HEAP_BYTES=([1-9][0-9]{9})$")
OOM_SUBTYPES = {
    "jvm-heap": re.compile(r"(?i)\b(?:Java heap space|GC overhead limit exceeded|Requested array size exceeds VM limit)\b"),
    "metaspace": re.compile(r"(?im)(?:OutOfMemoryError:|^e:)\s*(?:Metaspace|Compressed class space)\b"),
    "native-thread": re.compile(r"(?i)\bunable to create (?:new )?native thread\b"),
    "native-allocation": re.compile(r"(?i)\b(?:LLVM ERROR: out of memory|std::bad_alloc|Native memory allocation \(mmap\) failed|Direct buffer memory)\b"),
}

def extra_link_fields(gate, log, signatures):
    if gate != "ios-framework":
        return {}
    values = HEAP_PROOF.findall(log)
    heap = int(values[0]) if len(values) == 1 else None
    if heap is not None and not 3758096384 <= heap <= 4563402752:
        heap = None
    subtype = None
    if "out-of-memory" in signatures:
        matches = [name for name, rule in OOM_SUBTYPES.items() if rule.search(log)]
        subtype = matches[0] if len(matches) == 1 else "ambiguous" if matches else "unspecified"
    return {"effectiveLinkHeapBytes": heap, "oomSubtype": subtype}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("gate", choices=["ios-resolve", "ios-compile", "ios-framework"])
    parser.add_argument("code", type=int, choices=range(256))
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    log = args.log.read_text(errors="replace")
    task, category, signatures, causes = classify(log, args.code)
    print(json.dumps({"gate": args.gate, "exit": args.code, "firstFailedTask": task, "diagnosticCategory": category, "signatureKinds": signatures, "allowlistedCauseKinds": causes, **extra_link_fields(args.gate, log, signatures)}, sort_keys=True))
