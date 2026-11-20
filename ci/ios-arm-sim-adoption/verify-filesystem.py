#!/usr/bin/env python3
"""Audit a pre-existing public MadUIKit Maven stage, without Gradle or network."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile, BadZipFile

GROUP = "com.mad.maduikit"
VERSION = "0.1.0-alpha01"
PIN = "19c8c1b1fbe75b7d6a6118fdab42048948de091b"
MODULES = ("maduikit-components", "maduikit-theme")
TARGETS = {
    "iosarm64": ("native", "ios_arm64", ("kotlin-api",), "klib"),
    "iossimulatorarm64": ("native", "ios_simulator_arm64", ("kotlin-api",), "klib"),
    "android": ("androidJvm", None, ("java-api", "java-runtime"), "aar"),
    "iosx64": ("native", "ios_x64", ("kotlin-api",), "klib"),
}


def must(ok, description):
    if not ok:
        raise ValueError(description)


def unique(pairs):
    result = {}
    for key, value in pairs:
        must(key not in result, f"Duplicate metadata key: {key}")
        result[key] = value
    return result


def hash_file(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


class Stage:
    def __init__(self, root):
        self.root = root.absolute()
        must(self.root.is_dir() and self.root == self.root.resolve(),
             "Stage must be a real, canonical directory (no linked ancestors)")

    def file(self, relative):
        path = self.root / relative
        must(path.is_file() and path.resolve() == path, f"Missing or linked file: {relative}")
        return path

    def artifacts(self, directory, variants):
        known = {}
        for variant in variants:
            for ref in variant.get("files", []):
                name = ref["url"]
                must(re.fullmatch(r"[A-Za-z0-9._-]+", name) and name not in (".", ".."),
                     f"Not a local artifact basename: {name}")
                f = self.file(directory / name)
                if name not in known:
                    known[name] = dict(sha256=hash_file(f), size=f.stat().st_size)
                must(known[name] == {k: ref[k] for k in ("sha256", "size")},
                     f"Metadata bytes mismatch: {f.name}")
        return known

    def metadata(self, module, owner=None, extension=None):
        dir = Path(*GROUP.split("."), module, VERSION)
        stem = f"{module}-{VERSION}"
        f = self.file(dir / (stem + ".module"))
        must(f.stat().st_size <= 2_000_000, f"Metadata unusually large: {module}")
        data = json.loads(f.read_text(encoding="utf-8"), object_pairs_hook=unique)
        must(data.get("formatVersion") == "1.1" and
             all(data["component"][k] == v for k, v in
                 dict(group=GROUP, module=owner or module, version=VERSION).items()) and
             data["component"].get("url") == (f"../../{owner}/{VERSION}/{owner}-{VERSION}.module" if owner else None),
             f"Gradle component identity mismatch: {module}")
        pom = self.file(dir / (stem + ".pom"))
        xml = ET.parse(pom).getroot()
        must(all(xml.findtext("{*}"+k) == v for k,v in
                 dict(groupId=GROUP, artifactId=module, version=VERSION).items()),
             f"POM identity mismatch: {module}")
        if owner:
            must(xml.findtext("{*}packaging") == extension, f"POM packaging mismatch: {module}")
            if owner == MODULES[0]:
                suffix = module.removeprefix(owner)
                # Android POM may depend directly on the platform module or its KMP root.
                allowed = ["maduikit-theme"+suffix, "maduikit-theme"] if extension == "aar" else ["maduikit-theme"+suffix]
                dependencies = xml.findall("{*}dependencies/{*}dependency")
                matches = [d for d in dependencies if d.findtext("{*}groupId") == GROUP
                           and d.findtext("{*}artifactId") in allowed]
                must(len(matches) == 1 and matches[0].findtext("{*}version") == VERSION,
                     f"POM transitive theme mismatch: {module}")
        return dir, data["variants"], {f.name:hash_file(f), pom.name:hash_file(pom)}


def select(variants, platform, target, usage, context):
    selected = []
    for v in variants:
        a = v["attributes"]
        if (a.get("org.gradle.category") == "library" and a.get("org.gradle.usage") == usage
            and a.get("org.jetbrains.kotlin.platform.type") == platform
            and a.get("org.jetbrains.kotlin.native.target") == target):
            selected.append(v)
    must(len(selected) == 1, f"Missing or ambiguous {context} variant {usage}")
    return selected[0]


def theme_edge(variant, context):
    matches = [d for d in variant.get("dependencies", [])
               if d.get("group") == GROUP and d.get("module") == "maduikit-theme"]
    must(len(matches) == 1 and matches[0].get("version") == {"requires": VERSION},
         f"Missing or wrong transitive theme coordinate: {context}")


def member(z, name, limit):
    info = [i for i in z.infolist() if i.filename == name]
    must(len(info) == 1 and 0 < info[0].file_size <= limit, f"Missing/ambiguous/oversized ZIP entry: {name}")
    return z.read(info[0])


def binary(path, extension, target):
    with ZipFile(path) as z:
        if extension == "aar":
            manifest = member(z, "AndroidManifest.xml", 1_000_000)
            ET.fromstring(manifest)
            with ZipFile(io.BytesIO(member(z, "classes.jar", 16_000_000))) as jar:
                must(any(n.endswith(".class") for n in jar.namelist()), "AAR classes.jar has no classes")
            return {"format":"AAR", "contents":"AndroidManifest.xml and classes.jar"}
        manifest = {}
        for line in member(z, "default/manifest", 64_000).decode("utf-8").splitlines():
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                must(k not in manifest, f"Duplicate KLIB manifest field: {k}")
                manifest[k] = v
        must(manifest.get("native_targets") == target and
             manifest.get("builtins_platform") == "NATIVE" and manifest.get("compiler_version") == "2.2.21",
             f"Unexpected KLIB target/compiler: {path.name}")
        return {"format":"KLIB", "native_targets":target, "compiler_version":manifest["compiler_version"]}


def audit(root, targets):
    s = Stage(root)
    result = {}
    for module in MODULES:
        rdir, rootvars, root_meta = s.metadata(module)
        common = select(rootvars, "common", None, "kotlin-metadata", module)
        if module == MODULES[0]:
            theme_edge(common, module + " common")
        must(any(p.endswith(".jar") for p in s.artifacts(rdir, [common])),
             f"Missing common metadata JAR: {module}")
        result[module] = {"rootMetadataSha256":root_meta,"targets":{}}
        for suffix in targets:
            platform, target, usages, extension = TARGETS[suffix]
            coord = f"{module}-{suffix}"
            directory, variants, metadata_hashes = s.metadata(coord, module, extension)
            records = s.artifacts(directory, variants)
            name = f"{coord}-{VERSION}.{extension}"
            for usage in usages:
                link = select(rootvars, platform, target, usage, module)["available-at"]
                must(link == dict(url=f"../../{coord}/{VERSION}/{coord}-{VERSION}.module",
                                  group=GROUP,module=coord,version=VERSION), f"Wrong root variant link: {coord} {usage}")
                variant = select(variants, platform, target, usage, coord)
                must("available-at" not in variant and
                     [v["url"] for v in variant["files"] if v["url"].endswith("."+extension)] == [name],
                     f"Wrong target binary reference: {coord} {usage}")
                if module == MODULES[0]:
                    theme_edge(variant, f"{coord} {usage}")
            result[module]["targets"][suffix] = {
                "targetMetadataSha256":metadata_hashes, "files":records,
                "binary":binary(s.file(directory/name), extension, target)
            }
    return {"gate":"filesystem publication structure only","expectedSdkSourcePin":PIN,
            "sourcePinVerifiedByThisTool":False,"allRequestedTargets":list(targets),"modules":result}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("stage", type=Path)
    p.add_argument("--target", action="append", choices=TARGETS, help="Partial audit only when specified")
    args=p.parse_args()
    try:
        print(json.dumps(audit(args.stage, args.target or ("iosarm64","iossimulatorarm64","android")), indent=2))
    except (ValueError, KeyError, TypeError, OSError, RuntimeError, BadZipFile, ET.ParseError) as e:
        print(f"Filesystem publication audit failed: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
