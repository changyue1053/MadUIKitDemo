"""Select one eligible installed synthetic iPhone simulator (no install/download)."""
import json,re,sys
items=json.load(sys.stdin)["devices"].get(sys.argv[1],[])
devices=sorted((d for d in items if d.get("isAvailable") is True
                and d.get("name","").startswith("iPhone ")
                and re.fullmatch(r"[A-Fa-f0-9-]{36}", d.get("udid",""))),
               key=lambda d:(d["name"],d["udid"]))
if devices:
    print(devices[0]["udid"])
