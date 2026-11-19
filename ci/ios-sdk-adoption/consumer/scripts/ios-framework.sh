#!/bin/sh
set -eu

# Xcode build phases often omit terminal-specific paths.
export PATH="${GRADLE_HOME:+${GRADLE_HOME}/bin:}/opt/homebrew/bin:/usr/local/bin:$PATH"
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
    JAVA_HOME="$(/usr/libexec/java_home -v 17)"
    export JAVA_HOME
fi
if [ "${OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED:-NO}" = "YES" ]; then
    exit 0
fi

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"
if [ -x ./gradlew ]; then
    exec ./gradlew :composeApp:embedAndSignAppleFrameworkForXcode
fi
if ! command -v gradle >/dev/null 2>&1; then
    printf '%s\n' 'Install Gradle 8.13 and put it on PATH or set GRADLE_HOME before building.' >&2
    exit 1
fi
exec gradle :composeApp:embedAndSignAppleFrameworkForXcode
