#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
probe="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${GITHUB_WORKSPACE:?Missing application checkout}"
demo="$GITHUB_WORKSPACE/composeApp/src/commonMain/kotlin/dev/maduikit/demo/generated/FigmaProfileScreen.generated.kt"
page="$GITHUB_WORKSPACE/ci-input/cpf-codegen/sample-gradient-output/FigmaProfileScreen.generated.kt"
page_sha=652457633b3e993965e4aefccc20e60ba0577b697ff04adc713bde7544e8e0e5
test "$(git -C "$GITHUB_WORKSPACE/ci-input/cpf-codegen" rev-parse HEAD)" = b174b847a6e4096924bb1026d1b94a8d9a0c49a8
printf '%s  %s\n' "$page_sha" "$page" "$page_sha" "$demo" | sha256sum -c -
cmp "$page" "$demo"
: "${RUNNER_TEMP:?Missing runner temp}"
: "${JAVA_HOME_17_X64:?Missing runner JDK 17}"
: "${ANDROID_HOME:?Missing runner Android SDK}"
export JAVA_HOME="$JAVA_HOME_17_X64"
export PATH="$JAVA_HOME/bin:$PATH"
[[ "$(uname -m)" == x86_64 && "$(uname -s)" == Linux ]]
[[ -f "$ANDROID_HOME/platforms/android-36/android.jar" ]]
python3 -c 'import sys; assert sys.version_info >= (3, 12)'
free -h
df -h "$RUNNER_TEMP"
minimum_kib=$((9 * 1024 * 1024))
avail_kib="$(df --output=avail -k "$RUNNER_TEMP" | tail -1 | tr -d '[:space:]')"
(( avail_kib >= minimum_kib )) || { echo 'Insufficient scratch space: need at least 9 GiB free; no deletion attempted.'; exit 2; }
mem_kib="$(awk '$1=="MemTotal:"{print $2}' /proc/meminfo)"
(( mem_kib >= 12 * 1024 * 1024 )) || { echo 'Need a standard public-repository x64 runner memory tier.'; exit 2; }
if [[ -r /sys/fs/cgroup/memory.max ]]; then
  cap="$(cat /sys/fs/cgroup/memory.max)"
  [[ "$cap" == max ]] || (( cap >= 12 * 1024 * 1024 * 1024 )) || { echo 'Runner cgroup memory cap below 12 GiB.'; exit 2; }
fi
root="$(mktemp -d "$RUNNER_TEMP/mad-cpf.XXXXXX")"
export GRADLE_USER_HOME="$root/gradle-home" KONAN_DATA_DIR="$root/konan" TMPDIR="$root/tmp"
mkdir -p "$GRADLE_USER_HOME" "$KONAN_DATA_DIR" "$TMPDIR"
sha=d725d707bfabd4dfdc958c624003b3c80accc03f7037b5122c4b1d0ef15cecab
curl --proto '=https' --fail --silent --show-error --location --retry 2 --max-time 180 \
  https://downloads.gradle.org/distributions/gradle-8.9-bin.zip -o "$root/gradle.zip"
printf '%s  %s\n' "$sha" "$root/gradle.zip" | sha256sum -c -
unzip -q "$root/gradle.zip" -d "$root"
rm -f "$root/gradle.zip"
export GIT_TERMINAL_PROMPT=0
git init --quiet "$root/upstream"
upstream=a049930ec7d874f292427288d5389acf4f98ed3b
timeout 120 git -C "$root/upstream" fetch --no-tags --depth=1 \
  https://gitcode.com/CPF-KMP-CMP/kmp-cmp-example.git "$upstream"
[[ "$(git -C "$root/upstream" rev-parse FETCH_HEAD)" == "$upstream" ]]
python3 "$probe/stage.py" --page "$page" --repo "$root/upstream" --commit "$upstream" --out "$root/project" --sdk "$GITHUB_WORKSPACE/ci-input/cpf-sdk"
cp "$root/project/sdk-source-provenance.json" "$GITHUB_WORKSPACE/cpf-sdk-provenance.json"
cd "$root/project"
gradle="$root/gradle-8.9/bin/gradle"
opts=(--console=plain --no-daemon --no-build-cache --max-workers=1
  "-Dorg.gradle.jvmargs=-Xmx6g -Dfile.encoding=UTF-8 -Djava.io.tmpdir=$TMPDIR"
  "-Djava.io.tmpdir=$TMPDIR")
timeout 1000 "$gradle" "${opts[@]}" :composeApp:compileKotlinOhosArm64 2>&1 | tee "$root/compile.log"
if grep -F "Couldn't resolve dependency 'project :maduikit-components'" "$root/compile.log"; then
  echo 'ARM64-only app still has target resolution mismatch'; exit 3
fi
k=composeApp/build/classes/kotlin/ohosArm64/main/klib/composeApp/default
grep -Fx 'native_targets=ohos_arm64' "$k/manifest"
grep -Fx 'compiler_version=2.2.21-1.2.0' "$k/manifest"
grep -aFq 'figmaAxisGradient' "$k/ir/strings.knt"
for module in maduikit-theme maduikit-components; do
  manifest="$module/build/classes/kotlin/ohosArm64/main/klib/$module/default/manifest"
  grep -Fx 'native_targets=ohos_arm64' "$manifest"
  grep -Fx 'compiler_version=2.2.21-1.2.0' "$manifest"
done
grep -aFq 'MadTheme' maduikit-theme/build/classes/kotlin/ohosArm64/main/klib/maduikit-theme/default/ir/strings.knt
grep -aFq 'MadFilterTabs' maduikit-components/build/classes/kotlin/ohosArm64/main/klib/maduikit-components/default/ir/strings.knt
"$gradle" "${opts[@]}" --offline :composeApp:dependencies --configuration ohosArm64CompileKlibraries > "$GITHUB_WORKSPACE/cpf-sdk-dependencies.txt"
grep -F 'project :maduikit-components' "$GITHUB_WORKSPACE/cpf-sdk-dependencies.txt"
grep -F 'project :maduikit-theme' "$GITHUB_WORKSPACE/cpf-sdk-dependencies.txt"
echo '### Resolved ARM64 renderer dependency coordinates'
grep -Ei 'skiko|org.jetbrains.compose.ui:ui' "$GITHUB_WORKSPACE/cpf-sdk-dependencies.txt"
echo '### Exact resolved renderer artifact SHA-256'
find "$GRADLE_USER_HOME/caches" -type f \( -name '*skiko*klib' -o -name 'ui-ohosarm64-*.klib' \) -exec sha256sum {} \;
df -h "$RUNNER_TEMP"
free -h
timeout 1000 "$gradle" "${opts[@]}" --offline :composeApp:linkDebugSharedOhosArm64 2>&1 | tee "$root/link.log"
bin=composeApp/build/bin/ohosArm64/debugShared
so="$bin/libkn.so"
header="$bin/libkn_api.h"
test -s "$so" && test -s "$header"
readelf -h "$so" > "$root/elf.header"
readelf --dyn-syms --wide "$so" > "$root/elf.dynamic-symbols"
grep -E 'Type:[[:space:]]+DYN' "$root/elf.header"
grep -E 'Machine:[[:space:]]+AArch64' "$root/elf.header"
awk '$7 != "UND" && $8 == "MainArkUIViewController" { found=1 } END { exit !found }' "$root/elf.dynamic-symbols"
grep -Fq 'MainArkUIViewController' "$header"
{
  echo '### CPF ARM64-only SDK project-overlay synthetic ARM64: compile and link verified'
  printf 'Shared gradient Kotlin SHA-256: `%s`\n' "$page_sha"
  echo 'Exact SDK common source modules with CPF build adapters; not original SDK build or published Maven compatibility.'
  echo 'Verified AArch64 ELF shared library and defined MainArkUIViewController export; no HAP, signature or runtime.'
  echo
  echo '```'
  sha256sum "$so" "$header"
  echo '```'
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

# Only reached after successful compile/link and native export checks.
python3 "$probe/capture-native.py" --bin "$bin" --out "$RUNNER_TEMP/cpf-native-capture"
