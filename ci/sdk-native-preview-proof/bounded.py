"""Bound a public Gradle checkpoint, killing its process group on expiry."""
import os
import signal
import subprocess
import sys
from pathlib import Path

limit, log, *command = sys.argv[1:]
with Path(log).open("w") as stream:
    process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        rc = process.wait(timeout=int(limit))
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        stream.write("\nCHECKPOINT TIMEOUT\n")
        rc = 124
sys.exit(rc if rc >= 0 else 128 - rc)
