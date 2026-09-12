#!/usr/bin/env python3
import hashlib
import pathlib
import stat
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = tuple(line.strip() for line in (ROOT / "package-manifest.txt").read_text().splitlines() if line.strip())

def verify(archive: pathlib.Path) -> None:
    with zipfile.ZipFile(archive) as bundle:
        infos = bundle.infolist()
        names = [info.filename for info in infos]
        for info in infos:
            path = pathlib.PurePosixPath(info.filename)
            if path.is_absolute() or ".." in path.parts or info.filename.endswith("/"):
                raise ValueError(f"unsafe archive path: {info.filename}")
            if stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError(f"symlink forbidden: {info.filename}")
        if len(names) != len(set(names)):
            raise ValueError("duplicate archive member")
        if tuple(sorted(names)) != tuple(sorted(MANIFEST)):
            raise ValueError(f"closed manifest mismatch: {names}")

def build(archive: pathlib.Path) -> None:
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for name in sorted(MANIFEST):
            source = ROOT / "addon" / name
            if not source.is_file() or source.is_symlink():
                raise ValueError(f"missing or unsafe source: {name}")
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, source.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    verify(archive)
    print(f"PACKAGE_SHA256={hashlib.sha256(archive.read_bytes()).hexdigest()}")

if len(sys.argv) != 3 or sys.argv[1] not in {"build", "verify"}:
    raise SystemExit("usage: package_addon.py build|verify ARCHIVE")
target = pathlib.Path(sys.argv[2])
build(target) if sys.argv[1] == "build" else verify(target)
