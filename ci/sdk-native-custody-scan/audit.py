"""Read-only fail-closed material scan; never packages or authorizes export."""
from collections import Counter
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import sys
import zipfile

PINS={
 "alpha01-calibration":("0.1.0-alpha01","0b43cedaa3d6a7733512cd63f5a047ce9b92b2dd89e091da445778e276f1dcf3"),
 "alpha03-exact":("0.1.0-alpha03-sdk-preview01","d7571cc7c6931e1ced4e3a89fbd9ecdfc18397dedf2b8f575363e1587d1872c6"),
 "alpha03-job-local":("0.1.0-alpha03-sdk-preview01",None),
}
GROUP="com/mad/maduikit"
TOP_SIZE=25*1024*1024
ENTRY_SIZE=8*1024*1024
TOTAL=96*1024*1024
MAX_RATIO=1024
MAD_TEXT_ENUM_CLASS="com/mad/maduikit/MadTextKt$WhenMappings.class"
IR=set("bodies.knb debugInfo.knd fileEntries.knf files.knf irDeclarations.knd irInlineDeclarations.knd signatures.knt strings.knt types.knt".split())
BASE={"theme": {"MadTheme"}, "components": {"MadButton","MadFilterTabs"}}
S1={"theme": {"MadSpacing","MadTypography","MadProvideTypography"}, "components": {"MadText"}}
SOURCE_HASH={
 "MadButton":"7d849b90677a58443f46ea6b62b31205f71d832988a979e9e2cf4d2de1db4cf0",
 "MadFilterTabs":"29029648364b5e0f76e55e2a6f8ab8d2c0c7ad968cdbf06efffe271e26342f05",
 "MadTheme":"08fe6f863523e2f974e6ef38aa881691acaced09e3c6b8cdc27741ad527211b0",
 "MadSpacing":"82f685cd96692702b9384d5f0091788739092cdb2678f2889dc55920abd7ec1d",
 "MadTypography":"99a0265444a19ae27da16450ba64343a67c8e8c415be4e20f3a55973cd4ac777",
 "MadProvideTypography":"25d57e1e48f1b494e872cc03593d83c7eb9e5337d1c07d8d7d81b33f92feb5c0",
 "MadText":"78525f3473e220c69c04d01886f149b89aa1e485691f8e92ec1bf687291d14e4",
}
CLASS={"theme":{"MadThemeKt","MadColors","MadColorDefaults","MadSpacing","MadSpacingDefaults","MadTypography","MadProvideTypographyKt"},
       "components":{"MadButtonKt","MadFilterTabsKt","MadTextKt","MadTextRole"}}
RULES={
 "absolute-local-path":rb"(?:/(?:Users|home|root|workspace|mnt|Volumes|private|tmp|var/tmp|opt/hostedtoolcache|builds|runner)/|[a-z]:[\\/](?:Users|Windows|Temp|build|work)[\\/])",
 "local-file-uri":rb"file:/+(?:(?:[a-z]:/)|(?:Users|home|root|tmp|workspace|private|var|mnt|Volumes)/)",
 "private-key":rb"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----",
 "access-token-pattern":rb"(?:gh[pousr]_[A-Za-z0-9_]{24,}|github_pat_[A-Za-z0-9_]{24,}|xox[baprs]-[A-Za-z0-9-]{12,}|AKIA[A-Z0-9]{16}|AIza[A-Za-z0-9_\-]{35})",
 "credential-assignment":rb"(?:password|secret|access[_-]?token|api[_-]?key)\s{0,4}[=:]\s{0,4}['\"][A-Za-z0-9+/=_\-]{12,}",
 "private-design-reference":rb"(?:figma\.com/(?:design|file|proto)/|private[_ /.-]+(?:assets|fixture|design|app)|BEGIN PROPRIETARY)",
}
PATTERNS={k: re.compile(v,re.I) for k,v in RULES.items()}
TEXT_EXT={".kt",".module",".json",".xml",".pom",".properties",".txt",".MF",".md5",".sha1",".sha256",".sha512"}
SOURCE_ROOT_PIN={
 "alpha01-calibration":"19c8c1b1fbe75b7d6a6118fdab42048948de091b",
 "alpha03-exact":"cec44952263f528bb3775f0af63af51b4a04b621",
 "alpha03-job-local":"cec44952263f528bb3775f0af63af51b4a04b621",
}


def sha(b): return hashlib.sha256(b).hexdigest()
def valid_name(n):
    p=PurePosixPath(n)
    return bool(n and len(n)<=255 and n.rstrip("/")==p.as_posix() and not p.is_absolute()
       and ".." not in p.parts and all(re.fullmatch(r"[a-zA-Z0-9_.@-]+",x) and x not in (".","..") for x in p.parts))


class Reject(ValueError): pass


class Scanner:
    def __init__(self, mode, source):
        self.mode=mode
        self.version=PINS[mode][0]
        self.source=source
        self.counts=Counter()
        self.findings=Counter()
        self.bytes=0

    def mark(self,b,role,text=False):
        self.bytes+=len(b)
        if self.bytes>TOTAL: raise Reject("global-expanded-byte-cap")
        if text:
            try: b.decode("utf-8")
            except UnicodeError: raise Reject("expected-text-not-utf8") from None
        # Cross-check literal/escaped and UTF-16-like strings; no raw spans returned.
        samples=(b,b.replace(b"\\/",b"/"),b.replace(b"\0",b""))
        for name,pat in PATTERNS.items():
            if any(pat.search(part) for part in samples):
                self.findings[role+":"+name]+=1
        self.counts[role]+=1

    def stage_file(self,n,b,sidecar_payload=None):
        parts=PurePosixPath(n).parts
        module=parts[3]
        family=module.split("-")[1]
        if family not in BASE: raise Reject("unknown-module")
        name=parts[-1]
        if len(b)>TOP_SIZE: raise Reject("stage-entry-size-cap")
        if name.endswith((".sha256",".sha512",".sha1",".md5")):
            ext=Path(name).suffix
            lengths={".sha256":64,".sha512":128,".sha1":40,".md5":32}
            if not re.fullmatch(rb"[0-9a-f]{"+str(lengths[ext]).encode()+rb"}\s?",b): raise Reject("invalid-digest-sidecar")
            if sidecar_payload is None or hashlib.new(ext[1:],sidecar_payload).hexdigest().encode()!=b.strip(): raise Reject("digest-sidecar-content-mismatch")
            self.mark(b,"checksum",True)
        elif name.endswith("-sources.jar"):
            self.archive(b,"sources",family,module)
        elif name.endswith("-metadata.jar"):
            self.archive(b,"empty-metadata",family,module)
        elif name.endswith(".aar"):
            self.archive(b,"aar",family,module)
        elif name.endswith(".klib"):
            self.archive(b,"klib",family,module)
        elif name.endswith(".kotlin_resources.zip"):
            self.archive(b,"resources",family,module)
        elif name.endswith(".jar"):
            self.archive(b,"root-metadata",family,module)
        elif Path(name).suffix in TEXT_EXT:
            self.mark(b,"maven-text",True)
        else: raise Reject("unknown-stage-file-format")

    def allowed(self,n,is_dir,role,family,module):
        core=f"com/mad/maduikit"
        public=BASE[family] | (S1[family] if self.mode in {"alpha03-exact","alpha03-job-local"} else set())
        tgt="ios_simulator_arm64" if module.endswith("-iossimulatorarm64") else "ios_arm64"
        link=r"linkdata/(?:module|package_com\.mad\.maduikit/(?:[0-9]{1,2}_maduikit\.knm)?)"
        if role=="aar":
            return not is_dir and n in {"R.txt","AndroidManifest.xml","classes.jar","META-INF/com/android/build/gradle/aar-metadata.properties"}
        if role=="classes":
            if is_dir: return n in {"META-INF/","com/","com/mad/","com/mad/maduikit/"}
            if n==f"META-INF/maduikit-{family}_release.kotlin_module": return True
            p=PurePosixPath(n)
            return p.parent.as_posix()==core and p.suffix==".class" and p.stem.split("$")[0] in CLASS[family] and re.fullmatch(r"[A-Za-z0-9_$]+",p.stem)
        if role=="sources":
            if is_dir: return n in {"META-INF/","commonMain/","commonMain/com/","commonMain/com/mad/","commonMain/com/mad/maduikit/"}
            return n=="META-INF/MANIFEST.MF" or n in {f"commonMain/{core}/{p}.kt" for p in public}
        if role=="empty-metadata": return n in {"META-INF/","META-INF/MANIFEST.MF"}
        if role=="resources": return is_dir and n in {"composeResources/",f"composeResources/com.mad.maduikit.maduikit_{family}.generated.resources/"}
        if role=="root-metadata":
            flat={"META-INF/","META-INF/MANIFEST.MF","META-INF/kotlin-project-structure-metadata.json",
                  "commonMain/","commonMain/default/","commonMain/default/manifest","commonMain/default/linkdata/","commonMain/default/resources/"}
            return n in flat or re.fullmatch(r"commonMain/default/"+link,n)
        if role=="klib":
            flat={"default/","default/manifest","default/ir/","default/linkdata/","default/resources/",
                  "default/targets/",f"default/targets/{tgt}/",f"default/targets/{tgt}/included/",f"default/targets/{tgt}/native/"}
            return n in flat or n in {"default/ir/"+x for x in IR} or re.fullmatch(r"default/"+link,n)
        return False

    def archive(self,b,role,family,module):
        if len(b)>TOP_SIZE: raise Reject("archive-size-cap")
        # Only an alpha03 Android components AAR's own nested classes.jar may
        # contain this exact Kotlin-generated enum dispatch class name.
        scoped_class=role=="classes" and family=="components" and module=="maduikit-components-android" and self.mode in {"alpha03-exact","alpha03-job-local"}
        with strict_zip(b,150,allow_mad_text_enum_class=scoped_class) as z:
            i=z.infolist()
            if role!="resources" and not i: raise Reject("empty-unexpected-container")
            self.counts["container-"+role]+=1
            for x in i:
                n=x.filename
                if not self.allowed(n,x.is_dir(),role,family,module): raise Reject("unknown-member-role-"+role)
                if x.file_size>ENTRY_SIZE or x.file_size>max(1,x.compress_size)*MAX_RATIO: raise Reject("member-size-ratio-cap")
                pay=z.read(x) # verifies CRC even though no file is extracted
                if x.is_dir():
                    if pay: raise Reject("nonempty-directory-entry")
                    continue
                if role=="aar" and n=="classes.jar":
                    self.archive(pay,"classes",family,module);continue
                if pay.startswith((b"PK\x03\x04",b"PK\x05\x06",b"\x1f\x8b\x08",b"\x7fELF",b"\xcf\xfa\xed\xfe",
                                  b"\xfe\xed\xfa\xcf",b"\xce\xfa\xed\xfe",b"\xfe\xed\xfa\xce",b"!<arch>\n",b"MZ")):
                    raise Reject("unexpected-embedded-binary")
                if n.endswith(".kt"):
                    expected=self.source/f"maduikit-{family}/src"/n.replace("commonMain/","commonMain/kotlin/",1)
                    digest=SOURCE_HASH[Path(n).stem]
                    if not expected.is_file() or sha(pay)!=digest or sha(expected.read_bytes())!=digest:
                        raise Reject("public-source-hash-mismatch")
                if n.endswith(".class") and pay[:4]!=b"\xca\xfe\xba\xbe": raise Reject("invalid-class-magic")
                redacted_role="klib-ir-file-path-table" if role=="klib" and n in ("default/ir/files.knf","default/ir/fileEntries.knf") else role
                self.mark(pay,redacted_role,Path(n).suffix in TEXT_EXT or n.endswith("/manifest"))


def strict_zip(b, cap, *, allow_mad_text_enum_class=False):
    if len(b)<22 or b[-22:-18]!=b"PK\x05\x06": raise Reject("archive-cap-or-envelope")
    _,disk,disk_cd,disc_count,count,cd_bytes,cd_start,comment=struct.unpack_from("<4s4H2IH",b,len(b)-22)
    if disk or disk_cd or disc_count!=count or comment or cd_start+cd_bytes!=len(b)-22:
        raise Reject("noncanonical-zip-envelope")
    z=zipfile.ZipFile(io.BytesIO(b))
    try:
        entries=z.infolist()
        if len(entries)!=count or count>cap or len({x.filename.casefold() for x in entries})!=count:
            raise Reject("archive-count-or-duplicate")
        at=0
        for x in sorted(entries,key=lambda k:k.header_offset):
            kind=stat.S_IFMT(x.external_attr>>16)
            scoped_name=allow_mad_text_enum_class and x.filename==MAD_TEXT_ENUM_CLASS and not x.is_dir()
            if ((not valid_name(x.filename) and not scoped_name) or x.comment or x.extra or x.flag_bits & ~0x800 or
                kind not in (0,stat.S_IFREG,stat.S_IFDIR) or x.compress_type not in (0,8)):
                raise Reject("unsafe-member-metadata")
            if at!=x.header_offset or at+30>cd_start: raise Reject("unexpected-zip-gap-or-local-header")
            sig,_,flg,method,_,_,crc,csize,usize,nlen,xlen=struct.unpack_from("<4s5H3I2H",b,at)
            if (sig!=b"PK\x03\x04" or xlen or (flg,method,crc,csize,usize)!=(x.flag_bits,x.compress_type,x.CRC,x.compress_size,x.file_size)
                    or b[at+30:at+30+nlen]!=x.filename.encode("ascii")):
                raise Reject("inconsistent-zip-local-header")
            at+=30+nlen+csize
        if at!=cd_start: raise Reject("unexpected-zip-gap-or-local-header")
        return z
    except Exception:
        z.close()
        raise


def validate(mode, stage, before, after, source):
    s=Scanner(mode,source)
    try:
        staging=before.read_bytes()
        if mode=="alpha03-job-local" and not stage.is_dir():
            raise Reject("job-local-stage-must-be-directory")
        if ((PINS[mode][1] is not None and sha(staging)!=PINS[mode][1]) or staging!=after.read_bytes()):
            raise Reject("pinned-stage-receipt-identity")
        data=json.loads(staging)
        files=data["files"]
        if data["version"]!=s.version or len(files)!=250: raise Reject("unexpected-stage-receipt")
        if stage.is_symlink(): raise Reject("unsafe-stage-layout")
        if stage.is_dir():
            children=list(stage.rglob("*"))
            if any(p.is_symlink() or not (p.is_file() or p.is_dir()) for p in children): raise Reject("unsafe-stage-layout")
            local={p.relative_to(stage).as_posix():p for p in children if p.is_file()}
            if set(local)!=set(files): raise Reject("stage-file-inventory-mismatch")
            if any(p.stat().st_size>TOP_SIZE for p in local.values()) or sum(p.stat().st_size for p in local.values())>TOTAL:
                raise Reject("stage-size-cap")
            payloads={n:p.read_bytes() for n,p in local.items()}
        else:
            if stage.stat().st_size>TOP_SIZE: raise Reject("outer-archive-size-cap")
            with strict_zip(stage.read_bytes(),250) as z:
                members=z.infolist()
                prefix="versioned-maven/"
                if (any(x.is_dir() or not x.filename.startswith(prefix) for x in members) or
                        {x.filename.removeprefix(prefix) for x in members}!=set(files)):
                    raise Reject("outer-archive-inventory-mismatch")
                if sum(x.file_size for x in members)>TOTAL or any(x.file_size>TOP_SIZE or x.file_size>max(1,x.compress_size)*MAX_RATIO for x in members):
                    raise Reject("outer-expansion-cap")
                payloads={x.filename.removeprefix(prefix):z.read(x) for x in members}
        for n,b in sorted(payloads.items()):
            if not valid_name(n) or not n.startswith(GROUP+"/"): raise Reject("unsafe-stage-file")
            if sha(b)!=files[n]:raise Reject("stage-file-sha-mismatch")
            ext=Path(n).suffix
            payload=payloads.get(n.removesuffix(ext)) if ext in {".sha256",".sha512",".sha1",".md5"} else None
            s.stage_file(n,b,payload)
    except (Reject,OSError,KeyError,ValueError,zipfile.BadZipFile,RuntimeError,struct.error) as e:
        s.findings[str(e) if isinstance(e,Reject) else "unclassified-validator-error"]+=1
    approved=not s.findings and mode in {"alpha03-exact","alpha03-job-local"}
    return {"status":"scanner-eligible-not-authorized" if approved else "blocked" if s.findings else "historical-calibration-only",
            "sdkPin":SOURCE_ROOT_PIN[mode],"receiptSha256":sha(staging) if 'staging' in locals() else None,
            "findings":dict(s.findings),"scanned":dict(s.counts),"expandedByteCount":s.bytes,
            "scope":"technical scanner only; does not create or authorize an archive"}


if __name__=="__main__":
    mode,stage,before,after,source=sys.argv[1:]
    result=validate(mode,*map(Path,(stage,before,after,source)))
    print(json.dumps(result,sort_keys=True,indent=2))
    raise SystemExit(1 if result["findings"] else 0)
