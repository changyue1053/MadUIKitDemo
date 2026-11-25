"""Minimize one known test summary to fixed statuses, never upload raw XCTest data."""
import json
from pathlib import Path
import re
import sys

PHASES = ("title", "nav-initial", "nav-first-selector", "nav-first-bounds", "nav-first-hit", "nav-held", "nav-second-selector", "nav-second-bounds", "nav-second-hit", "nav-accepted", "progress", "modal", "background", "cancel", "confirm", "restored")
MARK = re.compile(r"MAD-XCT-ASSERT\[(" + "|".join(PHASES) + r")\]")
IDENTITY = "BookFilterUITests/testAlpha19AtlasTransfer"
MAX_SUMMARY = 2_000_000

def sanitize(exit_code, summary_state, path):
    command = "passed" if exit_code == 0 else "exit-65" if exit_code == 65 else "exit-124-ambiguous" if exit_code == 124 else "other-failure"
    default = dict(command=command, summary=summary_state, outcome="unknown", assertionPhase="not-observed")
    if summary_state != "read":
        return default
    try:
        if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= MAX_SUMMARY:
            raise ValueError
        s = json.loads(path.read_bytes())
        keys = ("totalTestCount", "passedTests", "failedTests")
        if not isinstance(s, dict) or not all(type(s.get(k)) is int and 0 <= s[k] <= 100 for k in keys):
            raise ValueError
        total, passed, failed = (s[k] for k in keys)
        if passed + failed > total:
            raise ValueError
    except (OSError, ValueError, TypeError):
        return dict(default, summary="unrecognized")
    if exit_code == 0 and (total, passed, failed, s.get("result")) == (1, 1, 0, "Passed"):
        return dict(default, outcome="one-test-passed")
    if total == 0:
        return dict(default, outcome="no-completed-test-recorded")
    if (total, passed, failed, s.get("result")) != (1, 0, 1, "Failed"):
        return dict(default, outcome="inconsistent-or-incomplete-result")
    failures = s.get("testFailures")
    if not isinstance(failures,list) or not failures:
        return dict(default, outcome="test-failed-no-detail")
    phases = set()
    for f in failures:
        if not isinstance(f,dict) or f.get("testIdentifierString") not in {IDENTITY, IDENTITY+"()"}:
            continue
        detail = f.get("failureText")
        if isinstance(detail,str):
            phases.update(MARK.findall(detail))
    if len(phases)==1 and exit_code != 0:
        return dict(default, outcome="marked-assertion-failed", assertionPhase=next(iter(phases)))
    if len(phases)>1:
        return dict(default, outcome="test-failed-ambiguous-phase")
    return dict(default, outcome="test-failed-unmarked")

if __name__ == "__main__":
    code, state, summary, out = sys.argv[1:]
    if state not in {"read","missing-result-bundle","summary-unavailable"}:
        raise SystemExit("Unknown diagnostic state")
    with Path(out).open("x") as stream:
        json.dump(sanitize(int(code), state, Path(summary)),stream,sort_keys=True,indent=2)
        stream.write("\n")
