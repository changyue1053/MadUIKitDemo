"""Preflight only. No fallback acquisition, no path or raw JVM output in errors."""
import os
from pathlib import Path
import platform
import re
import subprocess
import sys


def select(env, detected_system, detected_isa, version):
    if detected_system!="Darwin" or detected_isa!="x86_64" or env.get("ImageOS")!="macos15":
        return "host-profile",None
    if not re.fullmatch(r"[0-9.]{5,35}",env.get("ImageVersion","")):
        return "runner-image",None
    toolcache=env.get("RUNNER_TOOL_CACHE")
    if not toolcache:
        return "stock-toolcache-missing",None
    toolcache=Path(toolcache).resolve()
    java=env.get("JAVA_HOME_17_X64")
    if not java:
        java=toolcache/"Java_Temurin-Hotspot_jdk"/"17.0.20-101"/"x64"/"Contents"/"Home"
    java=Path(java).resolve()
    if not java.is_relative_to(toolcache) or not java.is_dir() or not os.access(java/"bin/java",os.X_OK):
        return "stock-jdk17-missing",None
    try: ver=version(java/"bin/java")
    except (OSError,subprocess.SubprocessError):
        return "stock-jdk17-check-failed",None
    if not re.search(r'version "17\.',ver):
        return "stock-jdk17-version",None
    home=env.get("ANDROID_HOME") or env.get("ANDROID_SDK_ROOT")
    if not home or not (Path(home)/"platforms/android-36/android.jar").is_file():
        return "stock-sdk36-missing",None
    return "passed",(str(java),str(Path(home).resolve()))


def cli():
    result, paths=select(os.environ,platform.system(),platform.machine(),
        lambda binary:subprocess.run([str(binary),"-version"],stdout=subprocess.PIPE,
                                      stderr=subprocess.STDOUT,text=True,check=True,timeout=8).stdout)
    # Status enum is allowed; paths are written only to a private shell input file.
    d=Path(sys.argv[1])
    (d/"stock-status.txt").write_text(result+"\n")
    if not paths:
        return 1
    (d/"private-toolpaths.txt").write_text("\n".join(paths)+"\n")
    return 0


if __name__=="__main__":
    raise SystemExit(cli())
