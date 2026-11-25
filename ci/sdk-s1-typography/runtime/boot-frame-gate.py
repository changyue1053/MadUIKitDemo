"""Qualify one original Booted guest frame; never export logs or frame bytes."""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys

CAPTURE_SECONDS = (25, 40)
VALIDATE_SECONDS = 45
MAX_FRAME_BYTES = 12_000_000


def run_bounded(command, limit, logfile):
    with logfile.open("xb") as stream:
        try:
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
        except OSError:
            return "start-failed"
        try:
            code = process.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            return "timed-out"
        if code == 0:
            return "passed"
        return "exit-124" if code == 124 else "command-failed"


def qualify(sim, validator, work, receipt):
    attempts = []
    previous = None
    for number, limit in enumerate(CAPTURE_SECONDS, start=1):
        frame = work / f"boot-frame-{number}.png"
        row = dict(attempt=number, captureBudgetSeconds=limit, validateBudgetSeconds=VALIDATE_SECONDS,
                   capture="not-run", validator="not-run", comparison="not-available")
        attempts.append(row)
        row["capture"] = run_bounded(["xcrun", "simctl", "io", sim, "screenshot", str(frame)],
                                     limit, work / f"boot-capture-{number}.log")
        if row["capture"] == "passed":
            if frame.is_symlink() or not frame.is_file() or not 8 < frame.stat().st_size <= MAX_FRAME_BYTES:
                row["validator"] = "invalid-capture-file"
                break
            digest = hashlib.sha256(frame.read_bytes()).digest()
            if previous is not None:
                row["comparison"] = "unchanged-bytes" if previous == digest else "changed-bytes"
            previous = digest
            row["validator"] = run_bounded([str(validator), str(frame), "boot"], VALIDATE_SECONDS,
                                           work / f"boot-validate-{number}.log")
            if row["validator"] == "passed":
                if row["comparison"] == "unchanged-bytes":
                    row["validator"] = "unchanged-after-rejection"
                break
            # Existing ImageIO's stderr/proc exit cannot prove specifically black;
            # rejection is distinct from a validator timeout. Exactly one new capture
            # is allowed for the former. A byte repeat never waives validation.
            if row["validator"] == "command-failed":
                row["validator"] = "frame-rejected"
            else:
                break
        elif row["capture"] != "timed-out":
            # A child exit 124 is not the Python supervisor reaching its deadline.
            break
    passed = attempts[-1]["validator"] == "passed"
    with receipt.open("x") as stream:
        json.dump(dict(passed=passed, attempts=attempts), stream, sort_keys=True, indent=2)
        stream.write("\n")
    return passed


if __name__ == "__main__":
    sim, validator, work, receipt = sys.argv[1:]
    if not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", sim):
        raise SystemExit("Invalid qualified simulator identifier")
    try:
        result = qualify(sim, Path(validator), Path(work), Path(receipt))
    except OSError:
        raise SystemExit("Boot frame evidence I/O failed") from None
    sys.exit(0 if result else 1)
