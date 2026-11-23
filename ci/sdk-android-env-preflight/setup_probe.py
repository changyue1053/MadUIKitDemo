"""Setup-only Android emulator diagnostic, without guest boot or APK."""
from pathlib import Path
import hashlib
import json
import os
import platform
import re
import signal
import subprocess
import sys
import tempfile

IMAGE = "system-images;android-35;google_apis;x86_64"
SOURCE_RUN = "45205065554"
PINNED_IMAGE = "20261116.376.1"


def classify(raw):
    text = raw.lower()
    for label, pattern in (
        ("license-unaccepted", r"not accepted|licen[cs]e acceptance|accept.*licen[cs]e|licen[cs]e.*not.*accept"),
        ("kvm-permission", r"permission denied.*(?:/dev/kvm|kvm)|(?:/dev/kvm|kvm).*permission denied"),
        ("acceleration-unavailable", r"kvm.*(?:not installed|not available|not supported|not enabled)|hardware acceleration.*(?:not available|not supported)"),
        ("sdk-not-writable", r"read-only file system|failed to create.*(?:dir|folder)|permission denied"),
        ("official-download-or-transport", r"connection reset|timed out|ssl(?:handshake)?exception|unknownhost|failed to download|(?:http|response).*\b(?:403|404|429|500|503)\b"),
        ("named-package-unavailable", r"failed to find package|package .* not found|no packages found"),
        ("disk-space", r"no space left|insufficient disk space"),
        ("sdkmanager-java", r"java_home|unsupportedclassversionerror|could not find or load main class"),
    ):
        if re.search(pattern, text):
            return label
    return "unclassified-tool-error"


def execute(argv, env, limit, log_path):
    with log_path.open("wb") as log:
        child = subprocess.Popen(argv, env=env, stdin=subprocess.DEVNULL,
                                 stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return child.wait(timeout=limit), False
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
            return 124, True


def revision(root):
    file = root / "source.properties"
    match = re.search(r"(?m)^Pkg.Revision\s*=\s*([0-9.]+)\s*$", file.read_text(errors="replace")) if file.is_file() else None
    return match[1] if match else None


def licenses(sdk):
    root = sdk / "licenses"
    if not root.is_dir():
        return {}
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.iterdir() if p.is_file() and not p.is_symlink()}


def acceleration_ok(text):
    return re.search(r"(?mi)^accel:\s*\n0\s*\n[^\n]*installed and usable", text) is not None


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: setup_probe.py <private receipt JSON path>")
    dest = Path(sys.argv[1])
    runner = os.environ.get("ImageVersion", "")
    elem = {"scope": "Android SDK setup diagnosis only; no guest boot, APK, launch, screenshot, or acceptance",
            "referenceRun": SOURCE_RUN, "run": os.environ.get("GITHUB_RUN_ID"),
            "attempt": os.environ.get("GITHUB_RUN_ATTEMPT"), "commit": os.environ.get("GITHUB_SHA"),
            "runnerImage": runner if re.fullmatch(r"[0-9.]{5,35}", runner) else None,
            "sameReferenceImage": runner == PINNED_IMAGE,
            "stages": {}, "summary": "setup-not-qualified"}

    def save(gate, command, status, reason, **detail):
        elem["stages"][gate] = dict(command=command, status=status, reason=reason, **detail)
        dest.write_text(json.dumps(elem, sort_keys=True, indent=2)+"\n")

    try:
        assert platform.system() == "Linux" and platform.machine() in ("x86_64", "AMD64")
        assert os.environ.get("ImageOS") == "ubuntu24" and elem["runnerImage"]
    except AssertionError:
        save("runner", "runner identity from hosted metadata", "failed", "wrong-or-unknown-runner-profile")
        return 1
    sdk_home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    sdk = Path(sdk_home).resolve() if sdk_home else None
    if not sdk or not sdk.is_dir():
        save("sdk", "stock ANDROID_HOME/ANDROID_SDK_ROOT", "failed", "sdk-root-missing")
        return 1
    adb = sdk / "platform-tools/adb"
    emulator = sdk / "emulator/emulator"
    manager = sdk / "cmdline-tools/latest/bin/sdkmanager"
    stock = lambda p: p.is_file() and os.access(p, os.X_OK)

    def inspect(gate, path, cmd, package, allow_missing=False):
        exists = stock(path)
        ver = revision(package) if exists else None
        save(gate, cmd, "passed" if exists else "absent" if allow_missing else "failed",
             "stock-executable" if exists else "stock-executable-missing", revision=ver)
        return exists
    adb_ok = inspect("stock-adb", adb, "stock platform-tools/adb executable", sdk/"platform-tools")
    emulator_ok = inspect("stock-emulator", emulator, "stock emulator/emulator executable", sdk/"emulator", True)
    if not adb_ok:
        return 1
    kvm_ok = Path("/dev/kvm").exists() and os.access("/dev/kvm", os.R_OK | os.W_OK)
    save("stock-kvm", "stock /dev/kvm exists and standard user has R/W", "passed" if kvm_ok else "failed",
         "stock-acl-available" if kvm_ok else "stock-acl-unavailable")
    if not kvm_ok:
        return 1

    with tempfile.TemporaryDirectory(prefix="mad-android-setup-", dir=os.environ.get("RUNNER_TEMP")) as temp:
        temp = Path(temp)
        env = dict(os.environ, ANDROID_HOME=str(sdk), ANDROID_USER_HOME=str(temp/"android-user"))
        (temp/"android-user").mkdir()

        def install(gate, package, target):
            cmd = f"sdkmanager --sdk_root=<stock> {package}"
            if not stock(manager):
                save(gate, cmd, "failed", "stock-sdkmanager-missing")
                return False
            before = licenses(sdk)
            if "android-sdk-license" not in before:
                save(gate, cmd, "failed", "existing-compatible-license-not-established")
                return False
            if not os.access(target if target.exists() else target.parent if target.parent.exists() else sdk, os.W_OK):
                save(gate, cmd, "failed", "stock-sdk-not-writable")
                return False
            log = temp/(gate+".log")
            code, expired = execute([str(manager), f"--sdk_root={sdk}", package], env, 180, log)
            same = licenses(sdk) == before
            reason = ("license-files-changed-unexpectedly" if not same else "tool-timeout" if expired else
                      classify(log.read_text(errors="replace")) if code else "official-install-completed")
            save(gate, cmd, "passed" if code == 0 and same else "failed", reason,
                 exit=code, existingLicenseFilesUnchanged=same, revision=revision(target))
            return code == 0 and same

        if not emulator_ok:
            if not install("emulator-install", "emulator", sdk/"emulator"):
                return 1
        else:
            save("emulator-install", "sdkmanager --sdk_root=<stock> emulator", "skipped", "stock-emulator-present-no-update")
        ver = revision(sdk/"emulator")
        ready = stock(emulator) and ver is not None
        save("emulator-qualified-file", "emulator/emulator executable and Pkg.Revision", "passed" if ready else "failed",
             "exact-package-revision-recorded" if ready else "emulator-layout-or-revision-missing", revision=ver)
        if not ready:
            return 1

        log = temp/"accel.log"
        code, expired = execute([str(emulator), "-accel-check"], env, 20, log)
        message = log.read_text(errors="replace")
        usable = code == 0 and acceleration_ok(message)
        save("acceleration", "emulator -accel-check", "passed" if usable else "failed",
             "affirmative-kvm-probe" if usable else "tool-timeout" if expired else
             classify(message) if code else "no-affirmative-kvm-marker", exit=code)
        if not usable:
            return 1

        target = sdk/"system-images/android-35/google_apis/x86_64"
        present = lambda: (target/"system.img").is_file() and (target/"system.img").stat().st_size > 0 and revision(target) is not None
        if present():
            save("api35-image-install", f"sdkmanager --sdk_root=<stock> {IMAGE}", "skipped",
                 "stock-image-present-no-update", revision=revision(target))
        elif not install("api35-image-install", IMAGE, target):
            return 1
        good = present()
        if good:
            elem["summary"] = "setup-qualified-without-guest-or-apk"
        save("api35-image-qualified-files", "API35 google_apis x86_64 system.img and Pkg.Revision",
             "passed" if good else "failed", "exact-package-revision-recorded" if good else "image-layout-or-revision-missing",
             revision=revision(target))
        return 0 if good else 1


if __name__ == "__main__":
    raise SystemExit(main())
