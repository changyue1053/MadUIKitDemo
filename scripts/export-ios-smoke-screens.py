"""Export only the two intentionally retained native XCTest screen PNGs."""
import argparse
import json
from pathlib import Path
import re
import struct

def png_size(p):
    with p.open("rb") as f:
        h=f.read(24)
    if len(h)!=24 or h[:16]!=b"\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR":
        raise ValueError("Expected raw PNG attachment")
    return struct.unpack(">II",h[16:24])

def gather(manifest):
    if isinstance(manifest,list):
        for value in manifest:
            yield from gather(value)
    if isinstance(manifest,dict):
        if isinstance(manifest.get("exportedFileName"),str):
            yield manifest
        else:
            for value in manifest.values():
                yield from gather(value)

def export(attachments,output):
    manifest=json.loads((attachments/"manifest.json").read_bytes())
    sizes=[]
    for state in ("before","after"):
        name=f"MadUIKit-iOS-Books-{state}"
        found=[m for m in gather(manifest) if re.fullmatch(re.escape(name)+r"(?:[_. -].*)?", m.get("suggestedHumanReadableName",""))]
        if len(found)!=1:
            raise ValueError(f"Expected exactly one {name} screenshot attachment, found {len(found)}")
        exported=found[0]["exportedFileName"]
        if Path(exported).name!=exported or not exported.endswith(".png"):
            raise ValueError("Unexpected PNG attachment path")
        source=attachments/exported
        sizes.append(png_size(source))
        (output/f"{name}.png").write_bytes(source.read_bytes())
    if sizes[0]!=sizes[1] or min(sizes[0])<650:
        raise ValueError(f"Expected same unscaled iPhone screenshots, got {sizes}")
    if (output/"MadUIKit-iOS-Books-before.png").read_bytes()==(output/"MadUIKit-iOS-Books-after.png").read_bytes():
        raise ValueError("Expected different native before/after screenshots")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("attachments",type=Path); p.add_argument("output",type=Path)
    a=p.parse_args()
    export(a.attachments,a.output)
