#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
root="${RUNNER_TEMP:?}/mad-replay-success"
input="$RUNNER_TEMP/mad-replay-input"
mkdir "$root"
work="$(mktemp -d "$RUNNER_TEMP/mad-s0-android.XXXXXX")"
gate=archive-integrity
emulator_pid=
finish() {
  local code=$?
  trap - EXIT
  if [[ -n "$emulator_pid" ]]; then
    timeout 15 adb -s emulator-5554 emu kill > /dev/null 2>&1 || true
    kill "$emulator_pid" > /dev/null 2>&1 || true
  fi
  python3 - "$RUNNER_TEMP/mad-replay-diagnostic.json" "$gate" "$code" <<'PY'
import json, os, sys
from pathlib import Path
f, gate, code = sys.argv[1:]
Path(f).write_text(json.dumps(dict(scope="exact prior APK launch replay diagnostic", sourceRun="45193292225",
   sourceArtifact=14830601661,
   stage=gate, exit=int(code), run=os.environ["GITHUB_RUN_ID"],
   attempt=os.environ["GITHUB_RUN_ATTEMPT"], commit=os.environ["GITHUB_SHA"]), indent=2)+"\n")
PY
  exit "$code"
}
trap finish EXIT
exec >"$work/work.log" 2>&1
apk="$work/public-unified-books-android.apk"
python3 "$here/verify.py" extract "$input/original.zip" "$apk"
gate=stock-kvm-acl
test -r /dev/kvm && test -w /dev/kvm
gate=stock-android-sdk
: "${ANDROID_HOME:?}"
export ANDROID_USER_HOME="$work/android" ANDROID_EMULATOR_HOME="$work/android" ANDROID_AVD_HOME="$work/avd"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
mkdir -p "$ANDROID_AVD_HOME"
gate=stock-adb-and-emulator
test -x "$ANDROID_HOME/platform-tools/adb"
test -x "$ANDROID_HOME/emulator/emulator"
gate=accelerator
timeout 20 emulator -accel-check
gate=stock-or-official-api35-image
image="$ANDROID_HOME/system-images/android-35/google_apis/x86_64"
if [[ ! -s "$image/system.img" || ! -s "$image/source.properties" ]]; then
  test -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
  timeout 210 sdkmanager --sdk_root="$ANDROID_HOME" 'system-images;android-35;google_apis;x86_64' < /dev/null
fi
test -s "$image/system.img" && test -s "$image/source.properties"
gate=stock-build-tools
aapt="$(find "$ANDROID_HOME/build-tools" -mindepth 2 -maxdepth 2 -type f -name aapt -print | sort -V | tail -1)"
test -x "$aapt"
gate=apk-identity
app=dev.mad.adoption.unified
launcher=dev.mad.adoption.MainActivity
"$aapt" dump badging "$apk" > "$work/apk-id"
grep -Fq "package: name='$app'" "$work/apk-id"
grep -Fq "launchable-activity: name='$launcher'" "$work/apk-id"
gate=prepare-avd
printf 'no\n' | timeout 40 avdmanager create avd --name mad-s0-public --package 'system-images;android-35;google_apis;x86_64' --device pixel_2 --path "$ANDROID_AVD_HOME/mad-s0-public.avd"
emulator -avd mad-s0-public -port 5554 -accel on -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect -camera-back none -camera-front none > "$work/emulator.log" 2>&1 &
emulator_pid=$!
device() { timeout 20 adb -s emulator-5554 "$@"; }
gate=prepare-guest
timeout 140 adb -s emulator-5554 wait-for-device
booted=false
for i in $(seq 1 55); do
  kill -0 "$emulator_pid"
  if [[ "$(timeout 4 adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" == 1 ]]; then booted=true; break; fi
  sleep 2
done
test "$booted" = true
test "$(device shell getprop ro.build.version.sdk | tr -d '\r')" = 35
test "$(device shell getprop ro.product.cpu.abi | tr -d '\r')" = x86_64
device shell getprop ro.build.fingerprint | tr -d '\r' > "$work/fingerprint"
python3 - "$image/source.properties" "$work/fingerprint" "$work/guest.json" <<'PYGUEST'
import json, re, sys
from pathlib import Path
source, fp, dest = map(Path, sys.argv[1:])
revision = re.search(r"(?m)^Pkg.Revision=([0-9.]+)$", source.read_text())
fingerprint = fp.read_text().strip()
assert revision and re.fullmatch(r"[A-Za-z0-9_.:/-]{10,250}", fingerprint)
dest.write_text(json.dumps(dict(api=35,abi="x86_64",flavor="google_apis",
    imageRevision=revision.group(1),guestFingerprint=fingerprint)))
PYGUEST
device shell input keyevent 82
gate=install-exact-candidate
timeout 65 adb -s emulator-5554 install "$apk" >"$work/install"
grep -Fxq 'Success' "$work/install"
device logcat -c
gate=launch
device shell am start -W -n "$app/$launcher" > "$work/launch"
grep -Fq 'Status: ok' "$work/launch"
gate=labels-and-foreground
checked=false
for i in $(seq 1 5); do
  if device shell uiautomator dump /sdcard/mad-s0-window.xml && device pull /sdcard/mad-s0-window.xml "$work/window.xml" && python3 - "$work/window.xml" "$app" <<'PY'
import sys, xml.etree.ElementTree as ET
window = ET.parse(sys.argv[1])
app = sys.argv[2]
labels = {v for n in window.iter("node") if n.get("package")==app for key in ("text", "content-desc") if (v:=n.get(key))}
assert {"Independent iOS SDK consumer", "All books", "Favorites"} <= labels
PY
  then checked=true; break; fi
  sleep 2
done
test "$checked" = true
device shell dumpsys activity activities > "$work/activities"
grep -E 'mResumedActivity|topResumedActivity' "$work/activities" | grep -Fq "$app/$launcher"
device shell pidof "$app" | grep -Eq '^[0-9]+'
gate=original-android-screenshot
device exec-out screencap -p > "$root/MadUIKit-Android-Unified-Books.png"
device logcat -d > "$work/logcat"
if grep -Fq "Process: $app," "$work/logcat"; then exit 1; fi
gate=android-replay-acceptance
python3 "$here/verify.py" accept "$apk" "$root" "$work/guest.json"
gate=passed
