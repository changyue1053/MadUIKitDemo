"""Attest the host ImageIO executable with a local-only synthetic decode check."""
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys
from tempfile import TemporaryDirectory
import zlib


def require(condition, message):
    if not condition:
        raise ValueError(message)


def binary_sha(executable):
    require(executable.resolve(strict=True) == executable and not executable.is_symlink()
            and stat.S_ISREG(executable.lstat().st_mode)
            and os.access(executable, os.X_OK), "Not a native validator executable")
    payload = executable.read_bytes()
    require(len(payload) >= 32, "Truncated validator")
    magic, cpu, _, filetype, _, _, _, _ = struct.unpack_from("<8I", payload)
    require((magic, cpu, filetype) == (0xfeedfacf, 0x0100000c, 2),
            "Validator must be a thin ARM64 Mach-O executable")
    return hashlib.sha256(payload).hexdigest()


def png_chunk(tag, payload):
    body = tag + payload
    return struct.pack(">I",len(payload)) + body + struct.pack(">I",zlib.crc32(body))


def smoke_png(width, height, blank=False):
    rows = b"".join(b"\0" + bytes([80 if blank else y*255//height])*(width*3) for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" +
            png_chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0)) +
            png_chunk(b"IDAT",zlib.compress(rows,1)) + png_chunk(b"IEND",b""))


def prove(executable, source, receipt):
    digest = binary_sha(executable)
    accepted = dict(width=1206,height=2622,decodedPNG=True,nonblankCheck=True)
    with TemporaryDirectory(prefix=".validator-qa-",dir=executable.parent) as temporary:
        image=Path(temporary)/"synthetic-only.png"
        image.write_bytes(smoke_png(1206,2622))
        for mode in ("boot","books"):
            result = subprocess.run([str(executable),str(image),mode],capture_output=True,text=True,timeout=5,check=True)
            require(json.loads(result.stdout) == dict(accepted,profile=mode), "Validator did not decode the synthetic test image")
        for rejected in (smoke_png(1206,2622,blank=True),smoke_png(10,10),b"\x89PNG\r\n\x1a\n"):
            image.write_bytes(rejected)
            result = subprocess.run([str(executable),str(image),"boot"],capture_output=True,timeout=5)
            require(result.returncode != 0 and not result.stdout,"Validator accepted an invalid synthetic test image")
    require(binary_sha(executable)==digest,"Validator executable drifted during preflight")
    receipt.write_text(json.dumps(dict(schemaVersion=1,architecture="arm64",
        validatorSha256=digest,sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        scope="host validator preflight only; no simulator or app executed",
        smokeProfiles=["boot","books"],refused=["blank","dimensions","incomplete"]),indent=2)+"\n")


def verify(executable, receipt):
    expected=json.loads(receipt.read_text())["validatorSha256"]
    require(binary_sha(executable)==expected,"Validator executable no longer matches preflight")


if __name__=="__main__":
    args=list(map(Path,sys.argv[2:]))
    if sys.argv[1]=="prove":
        prove(*args)
    elif sys.argv[1]=="verify":
        verify(*args)
    else:
        raise SystemExit("Unknown validator attestation mode")
