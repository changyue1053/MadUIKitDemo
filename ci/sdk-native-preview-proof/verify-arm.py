"""Validate and reduce a pinned adopter report; never echo raw Gradle paths/logs."""
import json
import re
import sys
from pathlib import Path

V = "0.1.0-alpha03-sdk-preview01"
G = "com.mad.maduikit:"
N = {
    "debugCompileClasspath": ("-android", "org.jetbrains.kotlin.platform.type=androidJvm", "aar"),
    "iosSimulatorArm64CompileKlibraries": ("-iossimulatorarm64", "org.jetbrains.kotlin.native.target=ios_simulator_arm64", "klib"),
    "iosArm64CompileKlibraries": ("-iosarm64", "org.jetbrains.kotlin.native.target=ios_arm64", "klib"),
}


def check(report, stage, arm, conf):
    assert arm in ("maduikit-theme", "maduikit-components")
    assert stage["version"] == V
    suf, attr, ext = N[conf]
    roots = ["maduikit-theme"] if arm == "maduikit-theme" else ["maduikit-theme", "maduikit-components"]
    sdk = lambda m: f"{G}{m}:{V}"
    lines = report.splitlines()
    assert lines[:2] == [f"scope={arm}/{conf}", f"declaredSdkRoot={arm}"]
    edges = {x for x in lines if " -> " in x}
    direct = {x for x in edges if x.startswith("synthetic-consumer -> " + G)}
    wanted = f"synthetic-consumer -> {sdk(arm)}"
    # AGP may generate additional resolution graph constraint edges from the
    # synthetic project node. Direct declarations are verified in Gradle above.
    assert wanted in direct
    allowed = {f"synthetic-consumer -> {sdk(name)}" for m in roots for name in (m, m+suf)}
    assert direct <= (allowed if ext == "aar" else {wanted})
    required = {f"{sdk(m)} -> {sdk(m+suf)}" for m in roots}
    if arm == "maduikit-components":
        required.add(f"{sdk(arm+suf)} -> {sdk('maduikit-theme')}")
    assert required <= edges
    row = re.compile(r"^(com\.mad\.maduikit:maduikit-[a-z0-9-]+):([^:]+): [^,/\\]+\.(aar|klib), ([a-f0-9]{64}), \{([^}]+)\}$")
    artifacts = {}
    for ln in lines:
        if not ln.startswith(G) or " -> " in ln:
            continue
        m = row.fullmatch(ln)
        assert m and m[2] == V and m[3] == ext and attr in m[5].split(", ")
        mod = m[1].removeprefix(G)
        assert mod not in artifacts and m[4] == stage["leafs"][mod]["sha256"]
        artifacts[mod] = m[4]
    assert set(artifacts) == {m+suf for m in roots}
    return dict(root=arm, configuration=conf, selectedSdkArtifacts=artifacts, selectedSdkEdges=sorted(required),
                scope="artifact and graph check only; compile status recorded separately")


if __name__ == "__main__":
    report, stage, arm, conf = sys.argv[1:]
    print(json.dumps(check(Path(report).read_text(), json.loads(Path(stage).read_text()), arm, conf),
                     indent=2, sort_keys=True))
