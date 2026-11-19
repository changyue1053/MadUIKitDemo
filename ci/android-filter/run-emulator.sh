#!/usr/bin/env bash
set -euo pipefail
root="$(pwd)"
evidence="$root/ci-evidence/android-filter"
mkdir -p "$evidence"
exec > >(tee "$evidence/runtime.log") 2>&1
: "${ANDROID_HOME:?Hosted runner Android SDK required}"
export ANDROID_USER_HOME="${RUNNER_TEMP:?Hosted runner temp required}/mad-public-android"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
mkdir -p "$ANDROID_AVD_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
sdkmanager 'emulator' 'system-images;android-35;google_apis;x86_64'
# This dedicated hosted CI runner has no user device or private application state.
if test -e /dev/kvm && ! test -w /dev/kvm; then sudo chmod a+rw /dev/kvm; fi
emulator -accel-check
printf 'no\n' | avdmanager create avd --name mad-public-consumer --package 'system-images;android-35;google_apis;x86_64' --device pixel_2 --path "$ANDROID_AVD_HOME/mad-public-consumer.avd"
test -f "$ANDROID_AVD_HOME/mad-public-consumer.ini"
emulator -list-avds | grep -Fx mad-public-consumer
emulator -avd mad-public-consumer -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect -camera-back none -camera-front none > "$evidence/emulator.log" 2>&1 &
pid=$!
trap 'adb emu kill >/dev/null 2>&1 || true; kill "$pid" 2>/dev/null || true' EXIT
connected=false
for i in $(seq 1 120); do
  if ! kill -0 "$pid" 2>/dev/null; then cat "$evidence/emulator.log"; exit 1; fi
  if adb devices | grep -Eq '^emulator-[0-9]+[[:space:]]+device$'; then connected=true; break; fi
  sleep 2
done
test "$connected" = true
booted=false
for i in $(seq 1 120); do
  if test "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1; then booted=true; break; fi
  sleep 2
done
test "$booted" = true
adb shell input keyevent 82
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb install -r "$evidence/public-synthetic-demo.apk"
adb logcat -c
adb shell am start -W -n dev.maduikit.demo.p5/dev.maduikit.demo.MainActivity | tee "$evidence/launch.txt"
grep -F 'Status: ok' "$evidence/launch.txt"
visible=false
for i in $(seq 1 15); do
  adb shell uiautomator dump /sdcard/window.xml >/dev/null
  adb pull /sdcard/window.xml "$evidence/window.xml" >/dev/null
  if grep -Fq 'MadUIKit' "$evidence/window.xml"; then visible=true; break; fi
  sleep 2
done
test "$visible" = true
adb shell dumpsys activity activities > "$evidence/activities.txt"
grep -E 'mResumedActivity|topResumedActivity' "$evidence/activities.txt" | grep -F dev.maduikit.demo.p5
python3 ci/android-filter/interact.py "$evidence"
adb logcat -d > "$evidence/logcat.txt"
if grep -Fq 'FATAL EXCEPTION' "$evidence/logcat.txt"; then exit 1; fi
printf 'PASS: public Android native selection and disabled-tap no-op with exact staged SDK. Not private parity or device validation.\n' | tee "$evidence/runtime-result.txt"
(cd "$evidence" && sha256sum Android-Books-*.png bundle/* > evidence.sha256)
