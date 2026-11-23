"""Isolated public resolver diagnosis; no raw logs or staged binaries uploaded."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import tempfile

BASE = "4c10c401bdf59a8c3986b8489203214af711d810"
PIN = "19c8c1b1fbe75b7d6a6118fdab42048948de091b"
TASK = ":composeApp:verifyAndroidAdoption"
DETECTOR = re.compile(r"Configuration [^\n]* contains AndroidX dependencies, but the `android\.useAndroidX` property is not enabled", re.I)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def classifier(log):
    # Extract only the first Gradle causal block; never serialize any runner log text.
    causal = log.partition("* What went wrong:")[2].partition("* Try:")[0]
    if DETECTOR.search(causal):
        return "androidx-disabled-detector"
    if re.search(r"Could not (resolve|download|find|GET|HEAD)", causal):
        return "dependency-resolution"
    return "unclassified-cause" if causal.strip() else "no-causal-block"


def run(cwd, command, log, seconds, env=None):
    with log.open("wb") as out:
        p = subprocess.Popen(command, cwd=cwd, env=env, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return p.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGTERM)
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait()
            return 124


def git(*args, cwd=None):
    return subprocess.check_output(["git", *args], cwd=cwd).decode().strip()


def main():
    source = Path.cwd().resolve()
    out = Path(os.environ["RUNNER_TEMP"]) / "mad-androidx-diagnostic"
    out.mkdir()
    receipt = {"scope": "fresh same-stage public synthetic Android resolution diagnostic, no runtime",
               "base": BASE, "sdk": PIN, "commit": git("rev-parse", "HEAD"), "run": os.environ["GITHUB_RUN_ID"],
               "attempt": os.environ["GITHUB_RUN_ATTEMPT"], "task": TASK, "legs": {}, "status": "precheck"}
    def save(status):
        receipt["status"] = status
        (out / "receipt.json").write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
    save("precheck")
    assert platform.system() == "Darwin" and platform.machine() == "arm64"
    assert os.environ["ImageOS"] == "macos26"
    assert git("rev-parse", "HEAD^") == BASE
    assert set(git("diff", "--name-only", BASE, "HEAD").splitlines()) == {
        ".github/workflows/sdk-androidx-preflight.yml", "ci/sdk-androidx-preflight/probe.py"}
    pin_dir = source / "ci-input/sdk"
    assert git("rev-parse", "HEAD", cwd=pin_dir) == PIN
    with tempfile.TemporaryDirectory(prefix="mad-androidx-", dir=os.environ["RUNNER_TEMP"]) as work:
        w = Path(work)
        env = dict(os.environ)
        # iOS KLIB publication must use the same Xcode toolchain; no simulator is queried.
        env["DEVELOPER_DIR"] = "/Applications/Xcode_26.4.1.app/Contents/Developer"
        if not Path(env["DEVELOPER_DIR"]).is_dir():
            save("pinned-producer-xcode-unavailable")
            return 1
        assert not any("androidx" in k.lower() for k in env if k.startswith("ORG_GRADLE_PROJECT_"))
        assert not any("android.useAndroidX" in env.get(k, "") for k in
                       ("GRADLE_OPTS", "JAVA_OPTS", "JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS"))
        android = Path(env.get("ANDROID_HOME") or env["ANDROID_SDK_ROOT"])
        # Only install Android Platform 36 when the stock runner doesn't have it.
        env["ANDROID_HOME"] = str(android)
        if not (android / "platforms/android-36/android.jar").is_file():
            if run(w, [str(android / "cmdline-tools/latest/bin/sdkmanager"), f"--sdk_root={android}",
                       "platforms;android-36"], w / "android-sdk.log", 150, env):
                save("android-platform-unavailable")
                return 1
        sdk = w / "sdk"
        shutil.copytree(pin_dir, sdk, ignore=shutil.ignore_patterns(".git"))
        original = w / "consumer"
        shutil.copytree(source / "ci/ios-arm-sim-adoption/consumer", original)
        shutil.copy2(sdk / "gradlew", original)
        shutil.copytree(sdk / "gradle", original / "gradle")
        subprocess.run(["python3", str(source / "ci/sdk-unified-stage/consumer.py"), str(original)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert not any(re.search(r"(?m)^\s*android\.useAndroidX\s*[:=]", p.read_text())
                       for p in original.rglob("gradle.properties"))
        stage, seed = w / "stage", w / "producer-gradle"
        control = ["bash", "gradlew", "--no-daemon", "--console=plain"]
        tasks = [f":maduikit-{m}:publish{target}PublicationToMadUIKitLocalRepository"
                 for m in ("theme", "components")
                 for target in ("AndroidRelease", "IosArm64", "KotlinMultiplatform", "IosSimulatorArm64")]
        producer = run(sdk, control + [f"-PmaduikitStagingDir={stage}"] + tasks,
                       w / "producer.log", 900, dict(env, GRADLE_USER_HOME=str(seed)))
        receipt["producerExit"] = producer
        if producer:
            receipt["producerCause"] = classifier((w / "producer.log").read_text(errors="replace"))
            save("producer-failed")
            return 1
        verifier = ["python3", str(source / "ci/sdk-unified-stage/verify-stage.py"), str(stage)]
        if run(w, verifier, w / "stage-before.json", 40, env):
            save("stage-verifier-failed")
            return 1
        before = (w / "stage-before.json").read_bytes()
        manifest = json.loads(before)
        receipt["stageSha256"] = digest(before)
        receipt["stageFiles"] = len(manifest["files"])
        save("stage-verified")
        for leg in ("A", "B"):
            consumer, home = w / f"consumer-{leg}", w / f"gradle-{leg}"
            shutil.copytree(original, consumer)
            # Independent Gradle homes copied from the same successful producer, not from preceding leg.
            shutil.copytree(seed, home)
            cmd = control + [f"-PmadStage={stage}", TASK] + (["-Pandroid.useAndroidX=true"] if leg == "B" else [])
            log = w / f"resolver-{leg}.log"
            code = run(consumer, cmd, log, 180, dict(env, GRADLE_USER_HOME=str(home)))
            cause = "timeout" if code == 124 else classifier(log.read_text(errors="replace")) if code else None
            receipt["legs"][leg] = {"exit": code, "cause": cause}
            if not code:
                expected = {f"com.mad.maduikit:{m}:0.1.0-alpha01 sha256={h['sha256']}"
                            for m, h in manifest["leafs"].items() if m.endswith("-android")}
                rows = (consumer / "composeApp/build/reports/sdk-adoption-android.txt").read_text().splitlines()
                assert len(expected) == len(rows) == 2 and expected == set(rows)
                receipt["legs"][leg]["aarReceipt"] = sorted(expected)
                receipt["legs"][leg]["themeEdge"] = "passed exact existing selected-theme edge assertion"
            save("resolver-" + leg)
            if leg == "A" and cause != "androidx-disabled-detector":
                break
        after = run(w, verifier, w / "stage-after.json", 40, env)
        if after or before != (w / "stage-after.json").read_bytes():
            save("stage-mutated-or-invalid")
            return 1
        receipt["stageUnchanged"] = True
        if receipt["legs"].get("B", {}).get("exit") == 0:
            save("detector-confirmed-and-android-resolver-passed")
            return 0
        save("android-resolver-not-accepted")
        return 1


if __name__ == "__main__":
    try:
        rc = main()
    except Exception:
        print("Diagnostic setup or invariant failed; see bounded receipt if present.")
        rc = 1
    raise SystemExit(rc)
