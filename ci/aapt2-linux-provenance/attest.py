"""Attest exact official Google Maven AAPT2 POM and Linux classifier, metadata only."""
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from zipfile import ZipFile

BASE = "https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/8.11.1-12782657/"
SDK_PIN = "19c8c1b1fbe75b7d6a6118fdab42048948de091b"
COORD = "com.android.tools.build:aapt2:8.11.1-12782657"
NAMES = ("aapt2-8.11.1-12782657.pom", "aapt2-8.11.1-12782657-linux.jar")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        raise ValueError("Unexpected redirect from pinned official URL")


def fetch(suffix, cap):
    url = BASE + suffix
    with urllib.request.build_opener(NoRedirect()).open(
        urllib.request.Request(url, headers={"Accept-Encoding": "identity"}), timeout=20
    ) as response:
        if response.status != 200 or response.geturl() != url:
            raise ValueError(f"Unexpected origin/status for {suffix}")
        content = response.read(cap + 1)
        length = response.headers.get("Content-Length")
        if not 0 < len(content) <= cap or (length is not None and int(length) != len(content)):
            raise ValueError(f"Invalid length for {suffix}")
        return content


def verify_checksum(name, body):
    for algorithm, digits in (("sha256", 64), ("sha1", 40)):
        source = name + "." + algorithm
        try:
            published = fetch(source, 1024).decode("ascii").strip()
        except urllib.error.HTTPError as error:
            # Only documented unavailability of the stronger sidecar permits fallback.
            if algorithm == "sha256" and error.code == 404:
                continue
            raise
        matches = re.fullmatch(rf"([0-9a-fA-F]{{{digits}}})(?:\s+\*?{re.escape(name)})?", published)
        if matches is None or hashlib.new(algorithm, body).hexdigest() != matches[1].lower():
            raise ValueError(f"Invalid/mismatched published {algorithm}: {name}")
        return dict(algorithm=algorithm, source=BASE + source, published=matches[1].lower())
    raise ValueError(f"No official checksum sidecar: {name}")


def check_pom(body):
    root = ET.fromstring(body)
    expected = dict(groupId="com.android.tools.build", artifactId="aapt2", version="8.11.1-12782657", packaging="pom")
    for k, value in expected.items():
        matches = root.findall("{*}" + k)
        if len(matches) != 1 or matches[0].text != value:
            raise ValueError(f"POM identity mismatch: {k}")
    return expected


def check_jar(body):
    with ZipFile(io.BytesIO(body)) as archive:
        infos = archive.infolist()
        names = [entry.filename for entry in infos]
        if len(names) != len(set(names)) or names.count("aapt2") != 1:
            raise ValueError("Duplicate ZIP entry or missing aapt2")
        if len(names) > 20 or sum(i.file_size for i in infos) > 64_000_000 or archive.testzip() is not None:
            raise ValueError("Invalid or oversized ZIP")
        tool = archive.read("aapt2")
        if (len(tool) < 64 or tool[:7] != b"\x7fELF\x02\x01\x01"
                or struct.unpack("<H", tool[18:20])[0] != 62
                or struct.unpack("<H", tool[16:18])[0] not in (2, 3)):
            raise ValueError("Unexpected AAPT2 Linux classifier ELF")
    return dict(entry="aapt2", elf="ELF64 little-endian", machine=62, bytes=len(tool),
                sha256=hashlib.sha256(tool).hexdigest(), zipEntries=len(names))


def attest(name):
    body = fetch(name, 20_000_000 if name.endswith(".jar") else 100_000)
    checksum = verify_checksum(name, body)
    structure = (check_jar if name.endswith(".jar") else check_pom)(body)
    return dict(name=name, source=BASE + name, size=len(body), computedSha256=hashlib.sha256(body).hexdigest(),
                officialChecksum=checksum, structure=structure)


def main():
    output, commit = Path(sys.argv[1]), sys.argv[2]
    if not re.fullmatch("[0-9a-f]{40}", commit):
        raise ValueError("Missing exact workflow commit")
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(attest, NAMES))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as receipt:
        json.dump(dict(coordinate=COORD, sdkPin=SDK_PIN, agp="8.11.1", workflowCommit=commit,
                       origin=BASE, records=results, payloadsStored=False), receipt, indent=2)
        receipt.write("\n")


if __name__ == "__main__":
    main()
