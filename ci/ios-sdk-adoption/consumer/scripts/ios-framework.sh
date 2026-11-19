#!/bin/sh
set -eu
printf '%s\n' 'XCODE FRAMEWORK PHASE ENTER'
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec /usr/bin/python3 "$ROOT/scripts/verify-prebuilt.py"
