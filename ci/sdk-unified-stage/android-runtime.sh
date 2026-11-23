#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
root="${RUNNER_TEMP:?}/mad-s0-candidate"
work="$(mktemp -d "$RUNNER_TEMP/mad-s0-android.XXXXXX")"
gate=candidate-integrity
emulator_pid=
finish() {
  local code=$?
  trap - EXIT
  if [[ -n "$emulator_pid" ]]; then
    timeout 15 adb -s emulator-5554 emu kill > /dev/null 2>&1 || true
    kill "$emulator_pid" > /dev/null 2>&1 || true
  fi
  python3 - "$RUNNER_TEMP/mad-s0-android-diagnostic.json" "$gate" "$code" <<'PY'
import json, os, sys
from pathlib import Path
f, gate, code = sys.argv[1:]
Path(f).write_text(json.dumps(dict(scope="exact candidate Android launch diagnostic",
   stage=gate, exit=int(code), run=os.environ["GITHUB_RUN_ID"],
   attempt=os.environ["GITHUB_RUN_ATTEMPT"], commit=os.environ["GITHUB_SHA"]), indent=2)+"\n")
PY
  exit "$code"
}
trap finish EXIT
exec >"$work/work.log" 2>&1
python3 "$here/finalize.py" verify "$root"
gate=stock-kvm-acl
test -r /dev/kvm && test -w /dev/kvm
gate=android-environment
: "${ANDROID_HOME:?}"
export ANDROID_USER_HOME="$work/android" ANDROID_EMULATOR_HOME="$work/android" ANDROID_AVD_HOME="$work/avd"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
mkdir -p "$ANDROID_AVD_HOME"
timeout 210 sdkmanager 'emulator' 'system-images;android-35;google_apis;x86_64'
timeout 20 emulator -accel-check
aapt="$(find "$ANDROID_HOME/build-tools" -mindepth 2 -maxdepth 2 -type f -name aapt -print | sort -V | tail -1)"
test -x "$aapt"
gate=apk-identity
app=dev.mad.adoption.unified
launcher=dev.mad.adoption.MainActivity
apk="$root/public-unified-books-android.apk"
"$aapt" dump badging "$apk" > "$work/apk-id"
grep -Fq "package: name='$app'" "$work/apk-id"
grep -Fq "launchable-activity: name='$launcher'" "$work/apk-id"
gate=prepare-avd
printf 'no\n' | timeout 40 avdmanager create avd --name mad-s0-public --package 'system-images;android-35;google_apis;x86_64' --device pixel_2 --path "$ANDROID_AVD_HOME/mad-s0-public.avd"
emulator -avd mad-s0-public -port 5554 -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect -camera-back none -camera-front none > "$work/emulator.log" 2>&1 &
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
gate=final-dual-acceptance
python3 "$here/finalize.py" accept "$root"
gate=passed
